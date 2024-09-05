#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
wazuh_indexer_config_file="/etc/wazuh-indexer/opensearch.yml"
wazuh_indexer_jvm_options_file="/etc/wazuh-indexer/jvm.options"
wazuh_indexer_security_config="/etc/wazuh-indexer/opensearch-security"

function wazuh_indexer_configure() {
    common_logger "Configuring Wazuh indexer."

    # Backup original configuration
    cp ${wazuh_indexer_config_file} ${wazuh_indexer_config_file}.bak

    # Configure main settings
    configure_main_settings

    # Configure JVM options
    configure_jvm_options

    # Configure cluster settings
    configure_cluster_settings

    # Configure security settings
    configure_security_settings

    common_logger "Wazuh indexer configuration completed."
}

function configure_main_settings() {
    common_logger "Configuring main settings."

    cat << EOF > ${wazuh_indexer_config_file}
network.host: ${indexer_node_ips[pos]}
node.name: ${indxname}
cluster.initial_master_nodes: 
  - ${indexer_node_names[0]}
path.data: /var/lib/wazuh-indexer
path.logs: /var/log/wazuh-indexer
bootstrap.memory_lock: true

EOF

    common_logger "Main settings configured."
}

function configure_jvm_options() {
    common_logger "Configuring JVM options."

    # Calculate heap size (50% of available RAM, but not more than 32GB)
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    heap_size=$((total_ram / 2))
    if [ ${heap_size} -gt 32768 ]; then
        heap_size=32768
    fi

    sed -i "s/-Xms.*/-Xms${heap_size}m/" ${wazuh_indexer_jvm_options_file}
    sed -i "s/-Xmx.*/-Xmx${heap_size}m/" ${wazuh_indexer_jvm_options_file}

    common_logger "JVM options configured."
}

function configure_cluster_settings() {
    common_logger "Configuring cluster settings."

    if [ ${#indexer_node_names[@]} -gt 1 ]; then
        cat << EOF >> ${wazuh_indexer_config_file}
cluster.name: wazuh-indexer-cluster
discovery.seed_hosts:
EOF
        for ip in "${indexer_node_ips[@]}"; do
            echo "  - ${ip}" >> ${wazuh_indexer_config_file}
        done
    else
        echo "discovery.type: single-node" >> ${wazuh_indexer_config_file}
    fi

    common_logger "Cluster settings configured."
}

function configure_security_settings() {
    common_logger "Configuring security settings."

    cat << EOF >> ${wazuh_indexer_config_file}
plugins.security.ssl.transport.pemcert_filepath: /etc/wazuh-indexer/certs/${indxname}.pem
plugins.security.ssl.transport.pemkey_filepath: /etc/wazuh-indexer/certs/${indxname}-key.pem
plugins.security.ssl.transport.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.ssl.http.enabled: true
plugins.security.ssl.http.pemcert_filepath: /etc/wazuh-indexer/certs/${indxname}.pem
plugins.security.ssl.http.pemkey_filepath: /etc/wazuh-indexer/certs/${indxname}-key.pem
plugins.security.ssl.http.pemtrustedcas_filepath: /etc/wazuh-indexer/certs/root-ca.pem
plugins.security.allow_unsafe_democertificates: false
plugins.security.allow_default_init_securityindex: true
plugins.security.authcz.admin_dn:
  - "CN=admin,OU=Wazuh,O=Wazuh,L=California,C=US"
plugins.security.check_snapshot_restore_write_privileges: true
plugins.security.enable_snapshot_restore_privilege: true
plugins.security.nodes_dn:
EOF

    for name in "${indexer_node_names[@]}"; do
        echo "  - 'CN=${name},OU=Wazuh,O=Wazuh,L=California,C=US'" >> ${wazuh_indexer_config_file}
    done

    common_logger "Security settings configured."
}

function wazuh_indexer_initialize_security() {
    common_logger "Initializing Wazuh indexer security settings."

    # Initialize the security plugin
    /usr/share/wazuh-indexer/plugins/opensearch-security/tools/securityadmin.sh \
        -cd ${wazuh_indexer_security_config} \
        -icl -nhnv \
        -cacert /etc/wazuh-indexer/certs/root-ca.pem \
        -cert /etc/wazuh-indexer/certs/${indxname}.pem \
        -key /etc/wazuh-indexer/certs/${indxname}-key.pem

    if [ $? -ne 0 ]; then
        common_logger -e "Failed to initialize Wazuh indexer security settings."
        exit 1
    fi

    common_logger "Wazuh indexer security settings initialized."
}

function wazuh_indexer_start() {
    common_logger "Starting Wazuh indexer."

    systemctl daemon-reload
    systemctl enable wazuh-indexer
    systemctl start wazuh-indexer

    if ! systemctl is-active --quiet wazuh-indexer; then
        common_logger -e "Wazuh indexer failed to start. Please check the logs."
        exit 1
    fi

    common_logger "Wazuh indexer started successfully."
}

# Export functions to be used in other scripts
export -f wazuh_indexer_configure
export -f configure_main_settings
export -f configure_jvm_options
export -f configure_cluster_settings
export -f configure_security_settings
export -f wazuh_indexer_initialize_security
export -f wazuh_indexer_start