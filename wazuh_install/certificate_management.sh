#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
cert_tmp_path="/tmp/wazuh-certificates"
cert_config_file="/tmp/wazuh-cert-config.yml"

# Certificate management functions

function cert_checkOpenSSL() {
    common_logger -d "Checking if OpenSSL is installed."
    if command -v openssl > /dev/null 2>&1; then
        common_logger -d "OpenSSL is installed."
    else
        common_logger -e "OpenSSL is not installed. Please install it and try again."
        exit 1
    fi
}

function cert_generateRootCAcertificate() {
    common_logger "Generating root CA certificate."
    if [ ! -d "${cert_tmp_path}" ]; then
        mkdir -p "${cert_tmp_path}"
    fi

    openssl req -x509 -new -nodes -newkey rsa:2048 \
        -keyout "${cert_tmp_path}/root-ca.key" \
        -out "${cert_tmp_path}/root-ca.pem" \
        -batch \
        -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=Wazuh Root CA" \
        -days 3650

    if [ $? -eq 0 ]; then
        common_logger -d "Root CA certificate generated successfully."
    else
        common_logger -e "Error generating root CA certificate."
        exit 1
    fi
}

function cert_generateCertificate() {
    local name=$1
    local ip=$2
    common_logger "Generating certificate for ${name}."

    # Generate private key
    openssl genrsa -out "${cert_tmp_path}/${name}-key.pem" 2048

    # Generate CSR
    openssl req -new -key "${cert_tmp_path}/${name}-key.pem" \
        -out "${cert_tmp_path}/${name}.csr" \
        -batch \
        -subj "/C=US/L=California/O=Wazuh/OU=Wazuh/CN=${name}"

    # Generate config file for SAN
    cat > "${cert_config_file}" <<- EOF
        [ v3_ext ]
        authorityKeyIdentifier=keyid,issuer
        basicConstraints=CA:FALSE
        keyUsage=keyEncipherment,dataEncipherment
        extendedKeyUsage=serverAuth,clientAuth
        subjectAltName=IP:${ip}
EOF

    # Generate certificate
    openssl x509 -req \
        -in "${cert_tmp_path}/${name}.csr" \
        -CA "${cert_tmp_path}/root-ca.pem" \
        -CAkey "${cert_tmp_path}/root-ca.key" \
        -CAcreateserial \
        -out "${cert_tmp_path}/${name}.pem" \
        -extfile "${cert_config_file}" \
        -extensions v3_ext \
        -days 3650

    if [ $? -eq 0 ]; then
        common_logger -d "Certificate for ${name} generated successfully."
    else
        common_logger -e "Error generating certificate for ${name}."
        exit 1
    fi

    # Clean up CSR and config file
    rm "${cert_tmp_path}/${name}.csr" "${cert_config_file}"
}

function cert_generateIndexerCertificates() {
    common_logger "Generating Wazuh indexer certificates."
    for i in "${!indexer_node_names[@]}"; do
        cert_generateCertificate "${indexer_node_names[i]}" "${indexer_node_ips[i]}"
    done
}

function cert_generateFilebeatCertificates() {
    common_logger "Generating Filebeat certificates."
    for i in "${!server_node_names[@]}"; do
        cert_generateCertificate "${server_node_names[i]}" "${server_node_ips[i]}"
    done
}

function cert_generateDashboardCertificates() {
    common_logger "Generating Wazuh dashboard certificates."
    for i in "${!dashboard_node_names[@]}"; do
        cert_generateCertificate "${dashboard_node_names[i]}" "${dashboard_node_ips[i]}"
    done
}

function cert_cleanFiles() {
    common_logger -d "Cleaning certificate files."
    find "${cert_tmp_path}" -type f -name "*.csr" -delete
    find "${cert_tmp_path}" -type f -name "*.srl" -delete
    rm -f "${cert_config_file}"
}

function cert_setPermissions() {
    common_logger -d "Setting permissions for certificate files."
    chmod 400 ${cert_tmp_path}/*
    chown wazuh:wazuh ${cert_tmp_path}/*
}

function cert_createCertificateTar() {
    common_logger "Creating tar file with certificates."
    tar -czf "${cert_tmp_path}/wazuh-certificates.tar.gz" -C "${cert_tmp_path}" .
    if [ $? -eq 0 ]; then
        common_logger -d "Certificate tar file created successfully."
    else
        common_logger -e "Error creating certificate tar file."
        exit 1
    fi
}

# Add more certificate management functions as needed

# Export functions to be used in other scripts
export -f cert_checkOpenSSL
export -f cert_generateRootCAcertificate
export -f cert_generateCertificate
export -f cert_generateIndexerCertificates
export -f cert_generateFilebeatCertificates
export -f cert_generateDashboardCertificates
export -f cert_cleanFiles
export -f cert_setPermissions
export -f cert_createCertificateTar