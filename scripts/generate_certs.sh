#!/bin/bash

mkdir -p logstash/certs

openssl req -x509 -newkey rsa:4096 -keyout logstash/certs/key.pem -out logstash/certs/root-ca.pem -days 365 -nodes -subj "/CN=opensearch"

echo "Self-signed certificates generated."