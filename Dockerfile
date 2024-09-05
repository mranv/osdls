# Use Rocky Linux as the base image
FROM rockylinux:8

# Set environment variables
ENV WAZUH_VERSION=4.8.2
ENV LOGSTASH_VERSION=8.15.0
ENV OPENSEARCH_USERNAME=admin
ENV OPENSEARCH_PASSWORD=Anubhav@321
ENV OPENSEARCH_HOST=localhost
ENV OPENSEARCH_PORT=9200
ENV LOGSTASH_KEYSTORE_PASS=Anubhav@321

# Update the system and install dependencies
RUN dnf update -y && \
    dnf install -y epel-release dnf-utils wget bzip2 policycoreutils-python-utils \
    python3 python3-devel findutils java-11-openjdk-devel && \
    dnf config-manager --set-enabled powertools && \
    dnf clean all

# Install Wazuh manager
RUN curl -o /tmp/GPG-KEY-WAZUH https://packages.wazuh.com/key/GPG-KEY-WAZUH && \
    rpm --import /tmp/GPG-KEY-WAZUH && \
    curl -o /tmp/wazuh-manager-${WAZUH_VERSION}-1.x86_64.rpm https://packages.wazuh.com/4.x/yum/wazuh-manager-${WAZUH_VERSION}-1.x86_64.rpm && \
    rpm -ivh /tmp/wazuh-manager*.rpm && \
    rm /tmp/GPG-KEY-WAZUH /tmp/wazuh-manager*.rpm

# Install Logstash
RUN rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch && \
    echo "[logstash-${LOGSTASH_VERSION}]" > /etc/yum.repos.d/logstash.repo && \
    echo "name=Elastic repository for ${LOGSTASH_VERSION} packages" >> /etc/yum.repos.d/logstash.repo && \
    echo "baseurl=https://artifacts.elastic.co/packages/8.x/yum" >> /etc/yum.repos.d/logstash.repo && \
    echo "gpgcheck=1" >> /etc/yum.repos.d/logstash.repo && \
    echo "gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch" >> /etc/yum.repos.d/logstash.repo && \
    echo "enabled=1" >> /etc/yum.repos.d/logstash.repo && \
    echo "autorefresh=1" >> /etc/yum.repos.d/logstash.repo && \
    echo "type=rpm-md" >> /etc/yum.repos.d/logstash.repo && \
    dnf install -y logstash-${LOGSTASH_VERSION} && \
    /usr/share/logstash/bin/logstash-plugin install logstash-output-opensearch

# Configure Wazuh manager
RUN /var/ossec/bin/wazuh-control start && \
    sleep 10 && \
    /var/ossec/bin/wazuh-control status && \
    /var/ossec/bin/wazuh-control stop

# Configure Logstash
RUN mkdir -p /etc/logstash/conf.d /etc/logstash/templates && \
    curl -o /etc/logstash/templates/wazuh.json https://packages.wazuh.com/integrations/opensearch/4.x-2.x/dashboards/wz-os-4.x-2.x-template.json && \
    chown -R logstash:logstash /etc/logstash/conf.d /etc/logstash/templates

# Add Logstash configuration
COPY logstash/config/wazuh-opensearch.conf /etc/logstash/conf.d/wazuh-opensearch.conf

# Set up Logstash keystore
RUN mkdir -p /etc/sysconfig && \
    echo "LOGSTASH_KEYSTORE_PASS=${LOGSTASH_KEYSTORE_PASS}" | tee /etc/sysconfig/logstash && \
    chown root:root /etc/sysconfig/logstash && \
    chmod 600 /etc/sysconfig/logstash && \
    /usr/share/logstash/bin/logstash-keystore --path.settings /etc/logstash create && \
    echo "${OPENSEARCH_USERNAME}" | /usr/share/logstash/bin/logstash-keystore --path.settings /etc/logstash add OPENSEARCH_USERNAME && \
    echo "${OPENSEARCH_PASSWORD}" | /usr/share/logstash/bin/logstash-keystore --path.settings /etc/logstash add OPENSEARCH_PASSWORD

# Add logstash user to wazuh group
RUN usermod -a -G wazuh logstash

# Expose Wazuh manager and Logstash ports
EXPOSE 1514/udp 1515/tcp 1516/tcp 55000/tcp 5044/tcp

# Create a startup script
RUN echo '#!/bin/bash' > /start.sh && \
    echo 'sed -i "s/<OPENSEARCH_ADDRESS>/${OPENSEARCH_HOST}:${OPENSEARCH_PORT}/g" /etc/logstash/conf.d/wazuh-opensearch.conf' >> /start.sh && \
    echo '/var/ossec/bin/wazuh-control start' >> /start.sh && \
    echo '/usr/share/logstash/bin/logstash -f /etc/logstash/conf.d/wazuh-opensearch.conf --path.settings /etc/logstash &' >> /start.sh && \
    echo 'tail -f /var/ossec/logs/ossec.log' >> /start.sh && \
    chmod +x /start.sh

# Set the entrypoint to our startup script
ENTRYPOINT ["/start.sh"]