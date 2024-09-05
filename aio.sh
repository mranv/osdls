#!/bin/bash

# Function to prompt for password
get_password() {
    local prompt="$1"
    local password
    while true; do
        read -s -p "$prompt: " password
        echo
        read -s -p "Confirm $prompt: " password2
        echo
        [ "$password" = "$password2" ] && break
        echo "Passwords do not match. Please try again."
    done
    echo "$password"
}

# Prompt for passwords
OPENSEARCH_INITIAL_ADMIN_PASSWORD=$(get_password "Enter OpenSearch initial admin password")
LOGSTASH_KEYSTORE_PASS=$(get_password "Enter Logstash keystore password")
OPENSEARCH_USERNAME="admin"
OPENSEARCH_PASSWORD=$(get_password "Enter OpenSearch password for Logstash")

# Export passwords as environment variables
export OPENSEARCH_INITIAL_ADMIN_PASSWORD
export LOGSTASH_KEYSTORE_PASS
export OPENSEARCH_USERNAME
export OPENSEARCH_PASSWORD

# Create Logstash directory structure
mkdir -p logstash/config logstash/pipeline logstash/certs

# Create logstash.yml
cat << EOF > logstash/config/logstash.yml
http.host: "0.0.0.0"
path.config: /usr/share/logstash/pipeline
xpack.monitoring.enabled: false
EOF

# Create pipelines.yml
cat << EOF > logstash/config/pipelines.yml
- pipeline.id: wazuh
  path.config: "/usr/share/logstash/pipeline/wazuh-opensearch.conf"
EOF

# Create wazuh-opensearch.conf
cat << EOF > logstash/pipeline/wazuh-opensearch.conf
input {
  file {
    id => "wazuh_alerts"
    codec => "json"
    start_position => "beginning"
    stat_interval => "1 second"
    path => "/var/ossec/logs/alerts/alerts.json"
    mode => "tail"
    ecs_compatibility => "disabled"
  }
}

output {
  opensearch {
    hosts => ["https://opensearch-node1:9200", "https://opensearch-node2:9200"]
    auth_type => {
      type => 'basic'
      user => '\${OPENSEARCH_USERNAME}'
      password => '\${OPENSEARCH_PASSWORD}'
    }
    index => "wazuh-alerts-4.x-%{+YYYY.MM.dd}"
    ssl => true
    ssl_certificate_verification => false
    template => "/etc/logstash/templates/wazuh.json"
    template_name => "wazuh"
    template_overwrite => true
  }
}
EOF

# Generate self-signed certificate (for testing purposes only)
openssl req -x509 -newkey rsa:4096 -keyout logstash/certs/key.pem -out logstash/certs/root-ca.pem -days 365 -nodes -subj "/CN=opensearch"

# Backup existing docker-compose.yml
cp docker-compose.yml docker-compose.yml.bak

# Add Logstash service to docker-compose.yml
sed -i '/services:/a\
  logstash:\
    image: docker.elastic.co/logstash/logstash:7.10.2\
    container_name: logstash\
    volumes:\
      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro\
      - ./logstash/config:/usr/share/logstash/config:ro\
      - ./logstash/templates:/etc/logstash/templates:ro\
      - ./logstash/certs:/etc/logstash/certs:ro\
    environment:\
      LS_JAVA_OPTS: "-Xmx256m -Xms256m"\
      LOGSTASH_KEYSTORE_PASS: ${LOGSTASH_KEYSTORE_PASS}\
    networks:\
      - opensearch-net\
    depends_on:\
      - opensearch-node1\
      - opensearch-node2\
      - wazuh\
    command: >\
      bash -c '\''
        bin/logstash-plugin install --no-verify logstash-output-opensearch
        mkdir -p /etc/logstash/templates
        curl -o /etc/logstash/templates/wazuh.json https://packages.wazuh.com/integrations/opensearch/4.x-2.x/dashboards/wz-os-4.x-2.x-template.json
        echo "${LOGSTASH_KEYSTORE_PASS}" | bin/logstash-keystore --path.settings /usr/share/logstash/config create
        echo "${OPENSEARCH_USERNAME}" | bin/logstash-keystore --path.settings /usr/share/logstash/config add OPENSEARCH_USERNAME
        echo "${OPENSEARCH_PASSWORD}" | bin/logstash-keystore --path.settings /usr/share/logstash/config add OPENSEARCH_PASSWORD
        /usr/local/bin/docker-entrypoint
      '\'' ' docker-compose.yml

echo "Setup complete. Starting Docker Compose..."

# Start Docker Compose
docker-compose up -d

echo "Services are starting. You can check their status with 'docker-compose ps'"
echo "OpenSearch Dashboards will be available at http://localhost:5601 once it's fully started."