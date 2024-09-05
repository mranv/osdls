#!/bin/bash

set -e

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker and try again."
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "Docker daemon is not running. Please start Docker and try again."
    exit 1
fi

# Check for Docker Compose and set the appropriate command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

# Generate certificates
./scripts/generate_certs.sh

# Start Docker Compose
$DOCKER_COMPOSE_CMD up -d

# Configure OpenSearch
./scripts/configure_opensearch.sh

echo "Setup complete. Services are starting."
echo "You can check their status with '$DOCKER_COMPOSE_CMD ps'"
echo "OpenSearch Dashboards will be available at http://localhost:5601 once it's fully started."