#!/bin/bash

set -e

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

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker and try again."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "Docker daemon is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

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
# Using awk instead of sed for better multi-line insertion
awk '/services:/{print;print "  logstash:";print "    image: docker.elastic.co/logstash/logstash:7.10.2";print "    container_name: logstash";print "    volumes:";print "      - ./logstash/pipeline:/usr/share/logstash/pipeline:ro";print "      - ./logstash/config:/usr/share/logstash/config:ro";print "      - ./logstash/templates:/etc/logstash/templates:ro";print "      - ./logstash/certs:/etc/logstash/certs:ro";print "    environment:";print "      LS_JAVA_OPTS: \"-Xmx256m -Xms256m\"";print "      LOGSTASH_KEYSTORE_PASS: ${LOGSTASH_KEYSTORE_PASS}";print "    networks:";print "      - opensearch-net";print "    depends_on:";print "      - opensearch-node1";print "      - opensearch-node2";print "      - wazuh";print "    command: >";print "      bash -c '";print "        bin/logstash-plugin install --no-verify logstash-output-opensearch";print "        mkdir -p /etc/logstash/templates";print "        curl -o /etc/logstash/templates/wazuh.json https://packages.wazuh.com/integrations/opensearch/4.x-2.x/dashboards/wz-os-4.x-2.x-template.json";print "        echo \"${LOGSTASH_KEYSTORE_PASS}\" | bin/logstash-keystore --path.settings /usr/share/logstash/config create";print "        echo \"${OPENSEARCH_USERNAME}\" | bin/logstash-keystore --path.settings /usr/share/logstash/config add OPENSEARCH_USERNAME";print "        echo \"${OPENSEARCH_PASSWORD}\" | bin/logstash-keystore --path.settings /usr/share/logstash/config add OPENSEARCH_PASSWORD";print "        /usr/local/bin/docker-entrypoint";print "      '";next}1' docker-compose.yml > docker-compose.yml.new && mv docker-compose.yml.new docker-compose.yml

echo "Setup complete. Starting Docker Compose..."

# Start Docker Compose
docker-compose up -d

echo "Services are starting. You can check their status with 'docker-compose ps'"
echo "OpenSearch Dashboards will be available at http://localhost:5601 once it's fully started."