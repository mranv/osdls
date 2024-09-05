#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
wazuh_dashboard_config_file="/etc/wazuh-dashboard/opensearch_dashboards.yml"
wazuh_dashboard_plugin_dir="/usr/share/wazuh-dashboard/plugins/"

function wazuh_dashboard_install() {
    common_logger "Starting Wazuh dashboard installation."

    # Install Wazuh dashboard package
    if [ "${sys_type}" == "yum" ]; then
        eval "yum install wazuh-dashboard-${wazuh_version} -y ${debug}"
        install_result=$?
    elif [ "${sys_type}" == "apt-get" ]; then
        eval "apt-get update ${debug}"
        eval "apt-get install wazuh-dashboard=${wazuh_version}-* -y ${debug}"
        install_result=$?
    fi

    if [ $install_result -ne 0 ]; then
        common_logger -e "Wazuh dashboard installation failed."
        exit 1
    fi

    common_logger "Wazuh dashboard package installed successfully."

    # Initial configuration
    wazuh_dashboard_configure

    # Start Wazuh dashboard
    common_logger "Starting Wazuh dashboard."
    eval "systemctl daemon-reload ${debug}"
    eval "systemctl enable wazuh-dashboard.service ${debug}"
    eval "systemctl start wazuh-dashboard.service ${debug}"

    if ! systemctl is-active --quiet wazuh-dashboard; then
        common_logger -e "Wazuh dashboard did not start correctly. Check the log file for more details."
        exit 1
    fi

    common_logger "Wazuh dashboard installation completed."
}

function wazuh_dashboard_configure() {
    common_logger "Configuring Wazuh dashboard."

    # Backup original configuration
    cp ${wazuh_dashboard_config_file} ${wazuh_dashboard_config_file}.bak

    # Configure server settings
    configure_server_settings

    # Configure OpenSearch connection
    configure_opensearch_connection

    # Configure security settings
    configure_security_settings

    common_logger "Wazuh dashboard configuration completed."
}

function configure_server_settings() {
    common_logger "Configuring server settings."

    sed -i "s/^server.host:.*/server.host: \"${dashboard_node_ips[0]}\"/" ${wazuh_dashboard_config_file}
    sed -i "s/^server.port:.*/server.port: 443/" ${wazuh_dashboard_config_file}

    common_logger "Server settings configured."
}

function configure_opensearch_connection() {
    common_logger "Configuring OpenSearch connection."

    sed -i "s|^opensearch.hosts:.*|opensearch.hosts: [\"https://${indexer_node_ips[0]}:9200\"]|" ${wazuh_dashboard_config_file}

    common_logger "OpenSearch connection configured."
}

function configure_security_settings() {
    common_logger "Configuring security settings."

    cat << EOF >> ${wazuh_dashboard_config_file}
opensearch_security.auth.type: "saml"
opensearch_security.auth.anonymous_auth_enabled: false
opensearch_security.cookie.secure: true
opensearch_security.cookie.password: "$(openssl rand -hex 64)"
EOF

    common_logger "Security settings configured."
}

function wazuh_dashboard_post_install() {
    common_logger "Performing post-installation tasks."

    # Install Wazuh app for the dashboard
    install_wazuh_app

    # Configure SSL/TLS
    configure_ssl

    common_logger "Post-installation tasks completed."
}

function install_wazuh_app() {
    common_logger "Installing Wazuh app for the dashboard."

    wazuh_app_url="https://packages.wazuh.com/${wazuh_major}/ui/dashboard/wazuh-${wazuh_version}.zip"
    wazuh_app_file="wazuh-${wazuh_version}.zip"

    eval "curl -Lo /tmp/${wazuh_app_file} ${wazuh_app_url} ${debug}"
    eval "unzip /tmp/${wazuh_app_file} -d ${wazuh_dashboard_plugin_dir} ${debug}"
    eval "rm /tmp/${wazuh_app_file} ${debug}"

    common_logger "Wazuh app installed."
}

function configure_ssl() {
    common_logger "Configuring SSL/TLS for Wazuh dashboard."

    # Generate self-signed certificate (replace with your own certificates in production)
    openssl req -x509 -batch -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/wazuh-dashboard/dashboard.key \
        -out /etc/wazuh-dashboard/dashboard.crt \
        -subj "/C=US/ST=California/L=San Francisco/O=Wazuh/OU=Wazuh/CN=${dashboard_node_ips[0]}"

    # Update configuration to use SSL
    sed -i "s/^server.ssl.enabled:.*/server.ssl.enabled: true/" ${wazuh_dashboard_config_file}
    sed -i "s|^server.ssl.certificate:.*|server.ssl.certificate: /etc/wazuh-dashboard/dashboard.crt|" ${wazuh_dashboard_config_file}
    sed -i "s|^server.ssl.key:.*|server.ssl.key: /etc/wazuh-dashboard/dashboard.key|" ${wazuh_dashboard_config_file}

    common_logger "SSL/TLS configured for Wazuh dashboard."
}

# Export functions to be used in other scripts
export -f wazuh_dashboard_install
export -f wazuh_dashboard_configure
export -f configure_server_settings
export -f configure_opensearch_connection
export -f configure_security_settings
export -f wazuh_dashboard_post_install
export -f install_wazuh_app
export -f configure_ssl