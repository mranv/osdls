#!/bin/bash
set -e

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

# Generate certificates
if [ -f "./scripts/generate_certs.sh" ]; then
  ./scripts/generate_certs.sh
else
  echo "Certificate generation script not found. Skipping..."
fi

# Start Docker Compose
echo "Starting Docker Compose..."
$DOCKER_COMPOSE_CMD up -d

# Check if Docker Compose was successful
if [ $? -ne 0 ]; then
  echo "Error: Docker Compose failed to start the services."
  exit 1
fi

# Configure OpenSearch
if [ -f "./scripts/configure_opensearch.sh" ]; then
  ./scripts/configure_opensearch.sh
else
  echo "OpenSearch configuration script not found. Skipping..."
fi

echo "Setup complete. Services are starting."
echo "You can check their status with '$DOCKER_COMPOSE_CMD ps'"
echo "OpenSearch Dashboards will be available at http://localhost:5601 once it's fully started."
