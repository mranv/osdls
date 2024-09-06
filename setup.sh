#!/bin/bash
set -e

# Source the .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo ".env file not found in the current directory. Please create one with the required environment variables."
    exit 1
fi

# Function to check command existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Docker is installed and running
if ! command_exists docker; then
    echo "Docker is not installed. Please install Docker and try again."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "Docker daemon is not running. Please start Docker and try again."
    exit 1
fi

# Validate passwords
validate_password() {
    local pass="$1"
    local name="$2"
    if [[ ${#pass} -lt 8 || ! $pass =~ [A-Z] || ! $pass =~ [a-z] || ! $pass =~ [0-9] || ! $pass =~ [^a-zA-Z0-9] ]]; then
        echo "Error: $name does not meet the requirements."
        echo "It must be at least 8 characters long and contain at least one uppercase letter, one lowercase letter, one digit, and one special character."
        exit 1
    fi
}

validate_password "$OPENSEARCH_INITIAL_ADMIN_PASSWORD" "OPENSEARCH_INITIAL_ADMIN_PASSWORD"
validate_password "$OPENSEARCH_PASSWORD" "OPENSEARCH_PASSWORD"

# Run the individual scripts
echo "Generating SSL certificates..."
scripts/generate_certs.sh

echo "Building custom Docker image..."
scripts/build_image.sh

echo "Starting services..."
scripts/start_services.sh

echo "Configuring OpenSearch..."
scripts/configure_opensearch.sh

echo "Setup complete. Services are starting."
echo "You can check their status with 'docker-compose ps' or 'docker compose ps'"
echo "OpenSearch Dashboards will be available at https://localhost:5601 once it's fully started."
echo "Please wait a few minutes for all services to initialize completely."
echo "Please manually import Wazuh dashboards in OpenSearch Dashboards."
echo "Use the file: logstash/templates/wz-os-4.x-2.x-dashboards.ndjson"