#!/bin/bash
set -e

# Check for Docker Compose and set the appropriate command
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    echo "Docker Compose not found. Please install Docker Compose or Docker Compose v2 and try again."
    exit 1
fi

echo "Starting Docker Compose services..."
$DOCKER_COMPOSE_CMD up -d

# Check if Docker Compose was successful
if [ $? -ne 0 ]; then
    echo "Error: Docker Compose failed to start the services."
    exit 1
fi

echo "Services started successfully."