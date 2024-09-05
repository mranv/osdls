# Use Rocky Linux as the base image
FROM rockylinux:8

# Set environment variables
ENV WAZUH_VERSION=4.8.2
ENV LOGSTASH_VERSION=8.15.0
ENV OPENSEARCH_USERNAME=admin
ENV OPENSEARCH_PASSWORD=Anubhav@321

# Update the system and install dependencies
RUN dnf update -y && \
    dnf install -y epel-release dnf-utils && \
    dnf config-manager --set-enabled powertools && \
    dnf install -y wget bzip2 policycoreutils-python-utils \
    python3 python3-devel findutils && \
    dnf clean all

# Download Wazuh GPG key and manager package
RUN curl -o /tmp/GPG-KEY-WAZUH https://packages.wazuh.com/key/GPG-KEY-WAZUH && \
    curl -o /tmp/wazuh-manager-${WAZUH_VERSION}-1.x86_64.rpm https://packages.wazuh.com/4.x/yum/wazuh-manager-${WAZUH_VERSION}-1.x86_64.rpm

# Install Wazuh manager
RUN rpm --import /tmp/GPG-KEY-WAZUH && \
    rpm -ivh /tmp/wazuh-manager*.rpm && \
    rm /tmp/GPG-KEY-WAZUH /tmp/wazuh-manager*.rpm

# Configure Wazuh manager
RUN /var/ossec/bin/wazuh-keystore -f indexer -k username -v "${OPENSEARCH_USERNAME}" && \
    /var/ossec/bin/wazuh-keystore -f indexer -k password -v "${OPENSEARCH_PASSWORD}"

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

# Configure Logstash
RUN mkdir -p /etc/logstash/conf.d /etc/logstash/templates
COPY logstash/config/logstash.conf /etc/logstash/conf.d/wazuh-opensearch.conf
COPY logstash/templates/wazuh.json /etc/logstash/templates/wazuh.json
COPY logstash/Gemfile /opt/logstash/Gemfile

# Add logstash user to wazuh group
RUN usermod -a -G wazuh logstash

# Expose ports
EXPOSE 55000/tcp 1514/tcp 1515/tcp 514/udp 1516/tcp 5044/tcp

# Start Wazuh and Logstash
CMD ["/bin/bash", "-c", "systemctl enable wazuh-manager && systemctl start wazuh-manager && /usr/bin/supervisord -n -c /etc/supervisord.conf"]