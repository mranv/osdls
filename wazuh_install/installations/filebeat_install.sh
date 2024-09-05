#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
filebeat_config_file="/etc/filebeat/filebeat.yml"
filebeat_wazuh_module="/etc/filebeat/modules.d/wazuh.yml"

function filebeat_install() {
    common_logger "Starting Filebeat installation."

    # Install Filebeat package
    if [ "${sys_type}" == "yum" ]; then
        eval "yum install filebeat-${filebeat_version} -y ${debug}"
        install_result=$?
    elif [ "${sys_type}" == "apt-get" ]; then
        eval "apt-get update ${debug}"
        eval "apt-get install filebeat=${filebeat_version}* -y ${debug}"
        install_result=$?
    fi

    if [ $install_result -ne 0 ]; then
        common_logger -e "Filebeat installation failed."
        exit 1
    fi

    common_logger "Filebeat package installed successfully."

    # Initial configuration
    filebeat_configure

    # Start Filebeat
    common_logger "Starting Filebeat."
    eval "systemctl daemon-reload ${debug}"
    eval "systemctl enable filebeat.service ${debug}"
    eval "systemctl start filebeat.service ${debug}"

    if ! systemctl is-active --quiet filebeat; then
        common_logger -e "Filebeat did not start correctly. Check the log file for more details."
        exit 1
    fi

    common_logger "Filebeat installation completed."
}

function filebeat_configure() {
    common_logger "Configuring Filebeat."

    # Backup original configuration
    cp ${filebeat_config_file} ${filebeat_config_file}.bak

    # Configure Filebeat settings
    configure_filebeat_settings

    # Configure Wazuh module
    configure_wazuh_module

    common_logger "Filebeat configuration completed."
}

function configure_filebeat_settings() {
    common_logger "Configuring Filebeat settings."

    cat << EOF > ${filebeat_config_file}
filebeat.modules:
- module: wazuh
  alerts:
    enabled: true
  archives:
    enabled: false

setup.template.json.enabled: true
setup.template.json.path: '/etc/filebeat/wazuh-template.json'
setup.template.json.name: 'wazuh'
setup.ilm.enabled: false

output.elasticsearch:
  hosts: ['https://${indexer_node_ips[0]}:9200']
  protocol: https
  username: ${filebeat_username}
  password: ${filebeat_password}
  ssl.verification_mode: full
  ssl.certificate_authorities: 
    - /etc/filebeat/certs/root-ca.pem
  ssl.certificate: "/etc/filebeat/certs/filebeat.pem"
  ssl.key: "/etc/filebeat/certs/filebeat-key.pem"

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
EOF

    common_logger "Filebeat settings configured."
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

function filebeat_post_install() {
    common_logger "Performing post-installation tasks."

    # Download Wazuh template for Filebeat
    eval "curl -so /etc/filebeat/wazuh-template.json https://raw.githubusercontent.com/wazuh/wazuh/$(echo ${wazuh_version} | cut -d . -f1,2)/extensions/elasticsearch/7.x/wazuh-template.json ${debug}"

    # Set permissions
    chmod go+r /etc/filebeat/wazuh-template.json

    common_logger "Post-installation tasks completed."
}

# Export functions to be used in other scripts
export -f filebeat_install
export -f filebeat_configure
export -f configure_filebeat_settings
export -f configure_wazuh_module
export -f filebeat_post_install