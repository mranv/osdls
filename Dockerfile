# Use Rocky Linux as the base image
FROM rockylinux:8

# Set environment variables
ARG WAZUH_VERSION=4.8.2
ARG LOGSTASH_VERSION=8.15.0
# Environment variables from .env file
ARG OPENSEARCH_INITIAL_ADMIN_PASSWORD
ARG LOGSTASH_KEYSTORE_PASS
ARG OPENSEARCH_USERNAME
ARG OPENSEARCH_PASSWORD

ENV WAZUH_VERSION=${WAZUH_VERSION}
ENV LOGSTASH_VERSION=${LOGSTASH_VERSION}
ENV OPENSEARCH_INITIAL_ADMIN_PASSWORD=${OPENSEARCH_INITIAL_ADMIN_PASSWORD}
ENV LOGSTASH_KEYSTORE_PASS=${LOGSTASH_KEYSTORE_PASS}
ENV OPENSEARCH_USERNAME=${OPENSEARCH_USERNAME}
ENV OPENSEARCH_PASSWORD=${OPENSEARCH_PASSWORD}

# Update the system and install dependencies
RUN dnf update -y && \
    dnf install -y epel-release dnf-utils && \
    dnf config-manager --set-enabled powertools && \
    dnf install -y wget bzip2 policycoreutils-python-utils \
    python3 python3-devel java-11-openjdk-devel && \
    dnf clean all

# Download Wazuh GPG key and manager package
RUN curl -o /tmp/GPG-KEY-WAZUH https://packages.wazuh.com/key/GPG-KEY-WAZUH && \
    curl -o /tmp/wazuh-manager-4.8.2-1.x86_64.rpm https://packages.wazuh.com/4.x/yum/wazuh-manager-4.8.2-1.x86_64.rpm

# Install Wazuh manager
RUN rpm --import /tmp/GPG-KEY-WAZUH && \
    rpm -ivh /tmp/wazuh-manager*.rpm && \
    rm /tmp/GPG-KEY-WAZUH /tmp/wazuh-manager*.rpm

# Configure Wazuh manager
RUN /var/ossec/bin/wazuh-keystore -f indexer -k username -v ${OPENSEARCH_USERNAME} && \
    /var/ossec/bin/wazuh-keystore -f indexer -k password -v ${OPENSEARCH_PASSWORD}

# Install Logstash
RUN rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch && \
    echo "[logstash-${LOGSTASH_VERSION}]" > /etc/yum.repos.d/logstash.repo && \
    echo "name=Elastic repository for ${LOGSTASH_VERSION} packages" >> /etc/yum.repos.d/logstash.repo && \
    echo "baseurl=https://artifacts.elastic.co/packages/${LOGSTASH_VERSION}/yum" >> /etc/yum.repos.d/logstash.repo && \
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
CMD systemctl enable wazuh-manager && \
    systemctl start wazuh-manager && \
    /usr/bin/supervisord -n -c /etc/supervisord.conf