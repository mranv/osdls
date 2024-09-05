#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
wazuh_indexer_config_file="/etc/wazuh-indexer/opensearch.yml"
wazuh_indexer_jvm_file="/etc/wazuh-indexer/jvm.options"

function wazuh_indexer_install() {
    common_logger "Starting Wazuh indexer installation."

    # Install Wazuh indexer package
    if [ "${sys_type}" == "yum" ]; then
        eval "yum install wazuh-indexer-${wazuh_version} -y ${debug}"
        install_result=$?
    elif [ "${sys_type}" == "apt-get" ]; then
        eval "apt-get update ${debug}"
        eval "apt-get install wazuh-indexer=${wazuh_version}-* -y ${debug}"
        install_result=$?
    fi

    if [ $install_result -ne 0 ]; then
        common_logger -e "Wazuh indexer installation failed."
        exit 1
    fi

    common_logger "Wazuh indexer package installed successfully."

    # Initial configuration
    wazuh_indexer_configure

    # Start Wazuh indexer
    common_logger "Starting Wazuh indexer."
    eval "systemctl daemon-reload ${debug}"
    eval "systemctl enable wazuh-indexer.service ${debug}"
    eval "systemctl start wazuh-indexer.service ${debug}"

    if ! systemctl is-active --quiet wazuh-indexer; then
        common_logger -e "Wazuh indexer did not start correctly. Check the log file for more details."
        exit 1
    fi

    common_logger "Wazuh indexer installation completed."
}

function wazuh_indexer_configure() {
    common_logger "Configuring Wazuh indexer."

    # Backup original configuration
    cp ${wazuh_indexer_config_file} ${wazuh_indexer_config_file}.bak

    # Configure cluster settings
    configure_cluster_settings

    # Configure JVM options
    configure_jvm_options

    common_logger "Wazuh indexer configuration completed."
}

function configure_cluster_settings() {
    common_logger "Configuring cluster settings."

    # Set cluster name
    sed -i 's/^cluster.name:.*/cluster.name: wazuh-cluster/' ${wazuh_indexer_config_file}

    # Set node name
    sed -i "s/^node.name:.*/node.name: ${indxname}/" ${wazuh_indexer_config_file}

    # Configure network host
    sed -i "s/^network.host:.*/network.host: ${indexer_node_ips[pos]}/" ${wazuh_indexer_config_file}

    # Configure discovery settings
    if [ ${#indexer_node_names[@]} -gt 1 ]; then
        echo "discovery.seed_hosts:" >> ${wazuh_indexer_config_file}
        for ip in "${indexer_node_ips[@]}"; do
            echo "  - ${ip}" >> ${wazuh_indexer_config_file}
        done
        echo "cluster.initial_master_nodes:" >> ${wazuh_indexer_config_file}
        for name in "${indexer_node_names[@]}"; do
            echo "  - ${name}" >> ${wazuh_indexer_config_file}
        done
    else
        echo "discovery.type: single-node" >> ${wazuh_indexer_config_file}
    fi

    # Add additional cluster settings as needed

    common_logger "Cluster settings configured."
}

function configure_jvm_options() {
    common_logger "Configuring JVM options."

    # Calculate heap size (50% of available RAM, but not more than 32GB)
    total_ram=$(free -m | awk '/^Mem:/{print $2}')
    heap_size=$((total_ram / 2))
    if [ ${heap_size} -gt 32768 ]; then
        heap_size=32768
    fi

    sed -i "s/-Xms.*/-Xms${heap_size}m/" ${wazuh_indexer_jvm_file}
    sed -i "s/-Xmx.*/-Xmx${heap_size}m/" ${wazuh_indexer_jvm_file}

    common_logger "JVM options configured."
}

function wazuh_indexer_initialize() {
    common_logger "Initializing Wazuh indexer."

    # Wait for Wazuh indexer to be ready
    common_logger "Waiting for Wazuh indexer to be ready..."
    while ! curl -XGET https://localhost:9200 -u admin:admin -k -s > /dev/null; do
        sleep 5
    done

    # Initialize Wazuh index
    common_logger "Creating Wazuh index."
    curl -XPUT "https://localhost:9200/wazuh" -u admin:admin -k -H "Content-Type: application/json" -d'
    {
        "settings": {
            "index.number_of_shards": 3,
            "index.number_of_replicas": 0
        }
    }' -s > /dev/null

    if [ $? -ne 0 ]; then
        common_logger -e "Failed to create Wazuh index."
        exit 1
    fi

    common_logger "Wazuh indexer initialized successfully."
}

# Export functions to be used in other scripts
export -f wazuh_indexer_install
export -f wazuh_indexer_configure
export -f configure_cluster_settings
export -f configure_jvm_options
export -f wazuh_indexer_initialize