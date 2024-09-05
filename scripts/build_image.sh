#!/bin/bash
set -e

echo "Building custom Docker image..."
docker build -t osdls:latest .
echo "Custom Docker image built."