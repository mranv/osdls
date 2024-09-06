#!/bin/bash


set -e

CERT_DIR="./opensearch/certs"
mkdir -p $CERT_DIR

# Generate root CA
openssl genrsa -out $CERT_DIR/root-ca-key.pem 2048
openssl req -new -x509 -sha256 -key $CERT_DIR/root-ca-key.pem -out $CERT_DIR/root-ca.pem -days 730 -subj "/C=IN/ST=Gujarat/L=Ahmedabad/O=INFOPERCEPT/CN=Root CA"

# Function to generate node certificate
generate_node_cert() {
    local NODE=$1
    openssl genrsa -out $CERT_DIR/$NODE-key.pem 2048
    openssl req -new -key $CERT_DIR/$NODE-key.pem -out $CERT_DIR/$NODE.csr -subj "/C=IN/ST=Gujarat/L=Ahmedabad/O=INFOPERCEPT/CN=$NODE"
    openssl x509 -req -in $CERT_DIR/$NODE.csr -CA $CERT_DIR/root-ca.pem -CAkey $CERT_DIR/root-ca-key.pem -CAcreateserial -out $CERT_DIR/$NODE.pem -days 365 -sha256
}

# Generate certificates for nodes
generate_node_cert "node1"
generate_node_cert "node2"

# Copy root CA to Logstash certs directory
mkdir -p ./logstash/certs
cp $CERT_DIR/root-ca.pem ./logstash/certs/

echo "Certificates generated successfully."
