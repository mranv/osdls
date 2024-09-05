#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
wazuh_manager_config_file="/var/ossec/etc/ossec.conf"

function wazuh_server_install() {
    common_logger "Starting Wazuh server installation."

    # Install Wazuh manager package
    if [ "${sys_type}" == "yum" ]; then
        eval "yum install wazuh-manager-${wazuh_version} -y ${debug}"
        install_result=$?
    elif [ "${sys_type}" == "apt-get" ]; then
        eval "apt-get update ${debug}"
        eval "apt-get install wazuh-manager=${wazuh_version}-* -y ${debug}"
        install_result=$?
    fi

    if [ $install_result -ne 0 ]; then
        common_logger -e "Wazuh manager installation failed."
        exit 1
    fi

    common_logger "Wazuh manager package installed successfully."

    # Initial configuration
    wazuh_server_configure

    # Start Wazuh manager
    common_logger "Starting Wazuh manager."
    eval "systemctl daemon-reload ${debug}"
    eval "systemctl enable wazuh-manager.service ${debug}"
    eval "systemctl start wazuh-manager.service ${debug}"

    if ! systemctl is-active --quiet wazuh-manager; then
        common_logger -e "Wazuh manager did not start correctly. Check the log file for more details."
        exit 1
    fi

    common_logger "Wazuh manager installation completed."
}

function wazuh_server_configure() {
    common_logger "Configuring Wazuh manager."

    # Backup original configuration
    cp ${wazuh_manager_config_file} ${wazuh_manager_config_file}.bak

    # Configure global settings
    configure_global_settings

    # Configure remote settings
    configure_remote_settings

    # Configure alerts
    configure_alerts

    # Configure active response
    configure_active_response

    # Configure cluster settings if applicable
    if [ ${#server_node_names[@]} -gt 1 ]; then
        configure_cluster_settings
    fi

    common_logger "Wazuh manager configuration completed."
}

function configure_global_settings() {
    common_logger "Configuring global settings."

    sed -i '/<global>/,/<\/global>/c\
  <global>\
    <jsonout_output>yes</jsonout_output>\
    <alerts_log>yes</alerts_log>\
    <logall>no</logall>\
    <logall_json>no</logall_json>\
    <email_notification>no</email_notification>\
    <smtp_server>smtp.example.wazuh.com</smtp_server>\
    <email_from>wazuh@example.wazuh.com</email_from>\
    <email_to>recipient@example.wazuh.com</email_to>\
    <email_maxperhour>12</email_maxperhour>\
  </global>' ${wazuh_manager_config_file}

    common_logger "Global settings configured."
}

function configure_remote_settings() {
    common_logger "Configuring remote settings."

    sed -i '/<remote>/,/<\/remote>/c\
  <remote>\
    <connection>secure</connection>\
    <port>1514</port>\
    <protocol>tcp</protocol>\
  </remote>' ${wazuh_manager_config_file}

    common_logger "Remote settings configured."
}

function configure_alerts() {
    common_logger "Configuring alerts."

    sed -i '/<alerts>/,/<\/alerts>/c\
  <alerts>\
    <log_alert_level>3</log_alert_level>\
    <email_alert_level>12</email_alert_level>\
  </alerts>' ${wazuh_manager_config_file}

    common_logger "Alerts configured."
}

function configure_active_response() {
    common_logger "Configuring active response."

    # This is a basic example. Adjust according to your needs.
    cat << EOF >> ${wazuh_manager_config_file}
  <active-response>
    <disabled>no</disabled>
    <ca_store>/var/ossec/etc/rootcheck/rootkit_files.txt</ca_store>
    <ca_store>/var/ossec/etc/rootcheck/rootkit_trojans.txt</ca_store>
  </active-response>
EOF

    common_logger "Active response configured."
}

function configure_cluster_settings() {
    common_logger "Configuring cluster settings."

    local node_type="worker"
    if [ "${server_node_names[0]}" == "${winame}" ]; then
        node_type="master"
    fi

    cat << EOF >> ${wazuh_manager_config_file}
  <cluster>
    <name>wazuh</name>
    <node_name>${winame}</node_name>
    <node_type>${node_type}</node_type>
    <key>$(openssl rand -hex 16)</key>
    <port>1516</port>
    <bind_addr>0.0.0.0</bind_addr>
    <nodes>
        <node>${server_node_ips[0]}</node>
    </nodes>
    <hidden>no</hidden>
    <disabled>no</disabled>
  </cluster>
EOF

    common_logger "Cluster settings configured."
}

function wazuh_server_post_install() {
    common_logger "Performing post-installation tasks."

    # Generate SSL certificate for OSSEC auth
    eval "/var/ossec/bin/ossec-authd -P > /dev/null 2>&1 &"

    # Wait for authd to start
    sleep 5

    # Stop authd
    eval "kill -TERM $(cat /var/ossec/var/run/ossec-authd.pid) ${debug}"

    common_logger "Post-installation tasks completed."
}

# Export functions to be used in other scripts
export -f wazuh_server_install
export -f wazuh_server_configure
export -f configure_global_settings
export -f configure_remote_settings
export -f configure_alerts
export -f configure_active_response
export -f configure_cluster_settings
export -f wazuh_server_post_install