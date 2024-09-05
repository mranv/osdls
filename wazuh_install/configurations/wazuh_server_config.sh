#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
wazuh_config_file="/var/ossec/etc/ossec.conf"
local_rules_file="/var/ossec/etc/rules/local_rules.xml"
wazuh_cluster_key_file="/var/ossec/etc/authd.pass"

function wazuh_server_configure() {
    common_logger "Configuring Wazuh server."

    # Backup the original configuration
    cp ${wazuh_config_file} ${wazuh_config_file}.bak

    # Configure ossec.conf
    configure_ossec_conf

    # Configure local rules
    configure_local_rules

    # Configure cluster if necessary
    if [ "${#server_node_names[@]}" -gt 1 ]; then
        configure_wazuh_cluster
    fi

    # Restart Wazuh manager
    common_logger "Restarting Wazuh manager."
    systemctl restart wazuh-manager

    common_logger "Wazuh server configuration completed."
}

function configure_ossec_conf() {
    common_logger "Configuring ossec.conf"

    # Example: Enable syscheck
    sed -i '/<syscheck>/,/<\/syscheck>/c\
  <syscheck>\
    <disabled>no</disabled>\
    <frequency>43200</frequency>\
    <scan_on_start>yes</scan_on_start>\
  </syscheck>' ${wazuh_config_file}

    # Example: Configure alerts
    sed -i '/<alerts>/,/<\/alerts>/c\
  <alerts>\
    <log_alert_level>3</log_alert_level>\
    <email_alert_level>12</email_alert_level>\
  </alerts>' ${wazuh_config_file}

    # Add more configuration changes as needed

    common_logger "ossec.conf configuration completed."
}

function configure_local_rules() {
    common_logger "Configuring local rules."

    # Example: Add a custom rule
    cat << EOF > ${local_rules_file}
<group name="local,">
  <rule id="100001" level="5">
    <if_sid>5716</if_sid>
    <description>Custom rule: User created</description>
  </rule>
</group>
EOF

    common_logger "Local rules configuration completed."
}

function configure_wazuh_cluster() {
    common_logger "Configuring Wazuh cluster."

    # Generate cluster key if it doesn't exist
    if [ ! -f "${wazuh_cluster_key_file}" ]; then
        openssl rand -hex 16 > ${wazuh_cluster_key_file}
    fi

    cluster_key=$(cat ${wazuh_cluster_key_file})

    # Configure cluster in ossec.conf
    sed -i '/<cluster>/,/<\/cluster>/d' ${wazuh_config_file}
    cat << EOF >> ${wazuh_config_file}
<cluster>
  <name>wazuh</name>
  <node_name>${server_node_names[0]}</node_name>
  <node_type>master</node_type>
  <key>${cluster_key}</key>
  <port>1516</port>
  <bind_addr>0.0.0.0</bind_addr>
  <nodes>
    <node>${server_node_ips[0]}</node>
EOF

    for ((i=1; i<${#server_node_names[@]}; i++)); do
        echo "    <node>${server_node_ips[i]}</node>" >> ${wazuh_config_file}
    done

    echo "  </nodes>
  <hidden>no</hidden>
  <disabled>no</disabled>
</cluster>" >> ${wazuh_config_file}

    common_logger "Wazuh cluster configuration completed."
}

function wazuh_server_set_indexer_connection() {
    common_logger "Setting Wazuh indexer connection."

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
  </global>\
\
  <remote>\
    <connection>secure</connection>\
    <port>1514</port>\
    <protocol>tcp</protocol>\
  </remote>\
\
  <reports>\
    <category>syscheck</category>\
    <title>Daily report: File changes</title>\
    <email_to>recipient@example.wazuh.com</email_to>\
  </reports>\
\
  <rootcheck>\
    <disabled>no</disabled>\
  </rootcheck>\
\
  <wodle name="cis-cat">\
    <disabled>yes</disabled>\
    <timeout>1800</timeout>\
    <interval>1d</interval>\
    <scan-on-start>yes</scan-on-start>\
\
    <java_path>wodles/java</java_path>\
    <ciscat_path>wodles/ciscat</ciscat_path>\
  </wodle>\
\
  <wodle name="osquery">\
    <disabled>yes</disabled>\
    <run_daemon>yes</run_daemon>\
    <log_path>/var/log/osquery/osqueryd.results.log</log_path>\
    <config_path>/etc/osquery/osquery.conf</config_path>\
    <add_labels>yes</add_labels>\
  </wodle>\
\
  <wodle name="syscollector">\
    <disabled>no</disabled>\
    <interval>1h</interval>\
    <scan_on_start>yes</scan_on_start>\
    <hardware>yes</hardware>\
    <os>yes</os>\
    <network>yes</network>\
    <packages>yes</packages>\
    <ports all="no">yes</ports>\
    <processes>yes</processes>\
  </wodle>\
\
  <wodle name="vulnerability-detector">\
    <disabled>no</disabled>\
    <interval>5m</interval>\
    <ignore_time>6h</ignore_time>\
    <run_on_start>yes</run_on_start>\
    <feed name="ubuntu-18">\
      <disabled>no</disabled>\
      <update_interval>1h</update_interval>\
    </feed>\
    <feed name="redhat">\
      <disabled>no</disabled>\
      <update_interval>1h</update_interval>\
    </feed>\
    <feed name="debian-9">\
      <disabled>no</disabled>\
      <update_interval>1h</update_interval>\
    </feed>\
  </wodle>\
\
  <sca>\
    <enabled>yes</enabled>\
    <scan_on_start>yes</scan_on_start>\
    <interval>12h</interval>\
    <skip_nfs>yes</skip_nfs>\
  </sca>' ${wazuh_config_file}

    common_logger "Wazuh indexer connection configured."
}

# Export functions to be used in other scripts
export -f wazuh_server_configure
export -f configure_ossec_conf
export -f configure_local_rules
export -f configure_wazuh_cluster
export -f wazuh_server_set_indexer_connection