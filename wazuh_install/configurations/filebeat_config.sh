#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
filebeat_config_file="/etc/filebeat/filebeat.yml"
filebeat_wazuh_module="/etc/filebeat/modules.d/wazuh.yml"
filebeat_wazuh_template="/etc/filebeat/wazuh-template.json"

function filebeat_configure() {
    common_logger "Starting Filebeat configuration."

    # Backup original configuration
    if [ -f "${filebeat_config_file}" ]; then
        cp ${filebeat_config_file} ${filebeat_config_file}.bak
    fi

    # Configure main Filebeat settings
    configure_filebeat_main

    # Configure Wazuh module
    configure_wazuh_module

    # Configure SSL/TLS
    configure_ssl

    # Load Wazuh template
    load_wazuh_template

    common_logger "Filebeat configuration completed."
}

function configure_filebeat_main() {
    common_logger "Configuring main Filebeat settings."

    cat << EOF > ${filebeat_config_file}
filebeat.modules:
- module: wazuh
  alerts:
    enabled: true
  archives:
    enabled: false

setup.template.json.enabled: true
setup.template.json.path: '${filebeat_wazuh_template}'
setup.template.json.name: 'wazuh'
setup.ilm.enabled: false

output.elasticsearch:
  hosts: ['https://${indexer_node_ips[0]}:9200']
  protocol: https
  username: ${filebeat_username}
  password: ${filebeat_password}

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
EOF

    common_logger "Main Filebeat settings configured."
}

function configure_wazuh_module() {
    common_logger "Configuring Wazuh module for Filebeat."

    cat << EOF > ${filebeat_wazuh_module}
- module: wazuh
  alerts:
    enabled: true
  archives:
    enabled: false
EOF

    common_logger "Wazuh module configured."
}

function configure_ssl() {
    common_logger "Configuring SSL/TLS for Filebeat."

    # Assuming certificates are already in place
    local ssl_cert_path="/etc/filebeat/certs"

    cat << EOF >> ${filebeat_config_file}

output.elasticsearch.ssl:
  enabled: true
  verification_mode: full
  certificate_authorities: ['${ssl_cert_path}/root-ca.pem']
  certificate: '${ssl_cert_path}/filebeat.pem'
  key: '${ssl_cert_path}/filebeat-key.pem'
EOF

    common_logger "SSL/TLS configured for Filebeat."
}

function load_wazuh_template() {
    common_logger "Loading Wazuh template for Filebeat."

    # Download Wazuh template if it doesn't exist
    if [ ! -f "${filebeat_wazuh_template}" ]; then
        eval "curl -so ${filebeat_wazuh_template} https://raw.githubusercontent.com/wazuh/wazuh/$(echo ${wazuh_version} | cut -d . -f1,2)/extensions/elasticsearch/7.x/wazuh-template.json ${debug}"
        
        if [ $? -ne 0 ]; then
            common_logger -e "Failed to download Wazuh template."
            return 1
        fi
    fi

    # Set correct permissions
    chmod 640 ${filebeat_wazuh_template}

    common_logger "Wazuh template loaded."
}

function filebeat_test_config() {
    common_logger "Testing Filebeat configuration."

    eval "filebeat test config -c ${filebeat_config_file} ${debug}"

    if [ $? -ne 0 ]; then
        common_logger -e "Filebeat configuration test failed."
        return 1
    fi

    common_logger "Filebeat configuration test passed."
}

function filebeat_restart() {
    common_logger "Restarting Filebeat service."

    eval "systemctl restart filebeat ${debug}"

    if [ $? -ne 0 ]; then
        common_logger -e "Failed to restart Filebeat."
        return 1
    fi

    common_logger "Filebeat service restarted."
}

# Main function to run all configuration steps
function filebeat_configure_all() {
    filebeat_configure
    filebeat_test_config
    filebeat_restart
}

# Export functions to be used in other scripts
export -f filebeat_configure
export -f configure_filebeat_main
export -f configure_wazuh_module
export -f configure_ssl
export -f load_wazuh_template
export -f filebeat_test_config
export -f filebeat_restart
export -f filebeat_configure_all