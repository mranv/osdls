#!/bin/bash
set -e

# Source the .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
else
    echo ".env file not found. Please create one with the required environment variables."
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

# Check for Docker Compose and set the appropriate command
if command_exists docker-compose; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "Docker Compose not found. Please install Docker Compose or Docker Compose v2 and try again."
    exit 1
fi

echo "Using Docker Compose command: $DOCKER_COMPOSE_CMD"

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

# Build the custom Docker image
echo "Building custom Docker image..."
docker build -t osdls:latest .

# Update the docker-compose.yml file to use the custom image
sed -i 's|image: wazuh/wazuh-manager:4.8.2|image: osdls:latest|g' docker-compose.yml

# Start Docker Compose
echo "Starting Docker Compose..."
$DOCKER_COMPOSE_CMD up -d

# Check if Docker Compose was successful
if [ $? -ne 0 ]; then
    echo "Error: Docker Compose failed to start the services."
    exit 1
fi

echo "Setup complete. Services are starting."
echo "You can check their status with '$DOCKER_COMPOSE_CMD ps'"
echo "OpenSearch Dashboards will be available at http://localhost:5601 once it's fully started."
echo "Please wait a few minutes for all services to initialize completely."
echo "Setup complete. Please import the Wazuh dashboards in OpenSearch Dashboards manually."
echo "Use the file: templates/wz-os-4.x-2.x-dashboards.ndjson"