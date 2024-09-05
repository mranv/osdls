#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
wazuh_dashboard_config_file="/etc/wazuh-dashboard/opensearch_dashboards.yml"
wazuh_dashboard_plugin_dir="/usr/share/wazuh-dashboard/plugins/"
wazuh_app_config_file="/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml"

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

    # Configure Wazuh app
    configure_wazuh_app

    common_logger "Wazuh dashboard configuration completed."
}

function configure_server_settings() {
    common_logger "Configuring server settings."

    cat << EOF > ${wazuh_dashboard_config_file}
server.host: "${dashboard_node_ips[0]}"
server.port: 443
server.ssl.enabled: true
server.ssl.certificate: "/etc/wazuh-dashboard/certs/dashboard.pem"
server.ssl.key: "/etc/wazuh-dashboard/certs/dashboard-key.pem"
EOF

    common_logger "Server settings configured."
}

function configure_opensearch_connection() {
    common_logger "Configuring OpenSearch connection."

    cat << EOF >> ${wazuh_dashboard_config_file}
opensearch.hosts: ["https://${indexer_node_ips[0]}:9200"]
opensearch.ssl.verificationMode: certificate
opensearch.ssl.certificateAuthorities: ["/etc/wazuh-dashboard/certs/root-ca.pem"]
opensearch.ssl.certificate: "/etc/wazuh-dashboard/certs/dashboard.pem"
opensearch.ssl.key: "/etc/wazuh-dashboard/certs/dashboard-key.pem"
EOF

    common_logger "OpenSearch connection configured."
}

function configure_security_settings() {
    common_logger "Configuring security settings."

    cat << EOF >> ${wazuh_dashboard_config_file}
opensearch_security.cookie.secure: true
opensearch_security.ssl.cert.client.pem: "/etc/wazuh-dashboard/certs/dashboard.pem"
opensearch_security.ssl.cert.client.key: "/etc/wazuh-dashboard/certs/dashboard-key.pem"
opensearch_security.ssl.cert.client.password: ${dashboard_cert_password}
EOF

    common_logger "Security settings configured."
}

function configure_wazuh_app() {
    common_logger "Configuring Wazuh app."

    mkdir -p "$(dirname "$wazuh_app_config_file")"

    cat << EOF > ${wazuh_app_config_file}
hosts:
  - production:
      url: https://${wazuh_server_ip}
      port: 55000
      username: ${wazuh_api_username}
      password: ${wazuh_api_password}
EOF

    common_logger "Wazuh app configured."
}

function wazuh_dashboard_enable_security() {
    common_logger "Enabling security for Wazuh dashboard."

    sed -i '/^opensearch_security/d' ${wazuh_dashboard_config_file}
    echo "opensearch_security.multitenancy.enabled: true" >> ${wazuh_dashboard_config_file}
    echo "opensearch_security.readonly_mode.roles: [\"kibana_read_only\"]" >> ${wazuh_dashboard_config_file}

    common_logger "Security enabled for Wazuh dashboard."
}

function wazuh_dashboard_configure_saml() {
    common_logger "Configuring SAML for Wazuh dashboard."

    cat << EOF >> ${wazuh_dashboard_config_file}
opensearch_security.auth.type: "saml"
opensearch_security.saml.idp.metadata.url: "${saml_idp_metadata_url}"
opensearch_security.saml.sp.entity_id: "wazuh-dashboard"
opensearch_security.saml.admin_role: "wazuh_admin"
opensearch_security.saml.attribute.principal: "email"
opensearch_security.saml.attribute.groups: "groups"
opensearch_security.saml.exchange_key: "$(openssl rand -hex 32)"
EOF

    common_logger "SAML configured for Wazuh dashboard."
}

function wazuh_dashboard_restart() {
    common_logger "Restarting Wazuh dashboard."

    systemctl restart wazuh-dashboard

    # Wait for the service to be fully operational
    sleep 10

    if systemctl is-active --quiet wazuh-dashboard; then
        common_logger "Wazuh dashboard restarted successfully."
    else
        common_logger -e "Failed to restart Wazuh dashboard. Check the logs for more information."
    fi
}

# Main function to orchestrate the configuration
function main() {
    wazuh_dashboard_configure
    wazuh_dashboard_enable_security

    # Uncomment the following line if you want to configure SAML
    # wazuh_dashboard_configure_saml

    wazuh_dashboard_restart
}

# Export functions to be used in other scripts
export -f wazuh_dashboard_configure
export -f configure_server_settings
export -f configure_opensearch_connection
export -f configure_security_settings
export -f configure_wazuh_app
export -f wazuh_dashboard_enable_security
export -f wazuh_dashboard_configure_saml
export -f wazuh_dashboard_restart
export -f main

# Run main function if the script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi