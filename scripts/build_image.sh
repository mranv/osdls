#!/bin/bash
set -e

echo "Copying SSL certificates..."
mkdir -p opensearch/certs
cp opensearch/certs/root-ca.pem logstash/certs/

echo "Building custom Docker image..."
docker build -t osdls:latest .
echo "Custom Docker image built."