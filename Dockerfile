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
    dnf install -y epel-release dnf-utils wget bzip2 gcc gcc-c++ make policycoreutils-python-utils \
    automake autoconf libtool openssl-devel curl-devel cmake python3 python3-devel java-11-openjdk-devel && \
    dnf clean all

# Install Wazuh manager
RUN curl -Ls https://github.com/wazuh/wazuh/archive/v${WAZUH_VERSION}.tar.gz | tar zx && \
    cd wazuh-${WAZUH_VERSION} && \
    ./install.sh && \
    cd .. && \
    rm -rf wazuh-${WAZUH_VERSION}

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
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]