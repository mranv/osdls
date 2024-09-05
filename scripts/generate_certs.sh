#!/bin/bash
set -e

echo "Generating SSL certificates..."
mkdir -p opensearch/certs
openssl req -x509 -newkey rsa:4096 -keyout opensearch/certs/root-ca-key.pem -out opensearch/certs/root-ca.pem -days 365 -nodes -subj "/CN=root-ca"
openssl req -newkey rsa:4096 -keyout opensearch/certs/node1-key.pem -out opensearch/certs/node1.csr -nodes -subj "/CN=node1"
openssl x509 -req -in opensearch/certs/node1.csr -CA opensearch/certs/root-ca.pem -CAkey opensearch/certs/root-ca-key.pem -CAcreateserial -out opensearch/certs/node1.pem -days 365
openssl req -newkey rsa:4096 -keyout opensearch/certs/node2-key.pem -out opensearch/certs/node2.csr -nodes -subj "/CN=node2"
openssl x509 -req -in opensearch/certs/node2.csr -CA opensearch/certs/root-ca.pem -CAkey opensearch/certs/root-ca-key.pem -CAcreateserial -out opensearch/certs/node2.pem -days 365
echo "SSL certificates generated."