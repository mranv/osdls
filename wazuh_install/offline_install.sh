#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
readonly base_dest_folder="/var/wazuh-offline-packages"
readonly wazuh_gpg_key="https://packages.wazuh.com/key/GPG-KEY-WAZUH"
readonly filebeat_config_file="${resources}/tpl/wazuh/filebeat/filebeat.yml"
readonly filebeat_wazuh_template="https://raw.githubusercontent.com/wazuh/wazuh/${source_branch}/extensions/elasticsearch/7.x/wazuh-template.json"
readonly filebeat_wazuh_module="${repobaseurl}/filebeat/wazuh-filebeat-0.4.tar.gz"

function offline_download() {
    common_logger "Starting Wazuh packages download."
    common_logger "Downloading Wazuh ${package_type} packages for ${arch}."
    dest_path="${base_dest_folder}/wazuh-packages"

    if [ -d "${dest_path}" ]; then
        eval "rm -f ${dest_path}/* ${debug}"
        eval "chmod 700 ${dest_path} ${debug}"
    else
        eval "mkdir -m700 -p ${dest_path} ${debug}"
    fi

    packages_to_download=( "manager" "filebeat" "indexer" "dashboard" )

    for package in "${packages_to_download[@]}"
    do
        common_logger -d "Downloading Wazuh ${package} package..."
        package_name="${package}_${package_type}_package"
        eval "package_base_url=${package}_${package_type}_base_url"

        if output=$(common_curl -sSo "${dest_path}/${!package_name}" "${!package_base_url}/${!package_name}" --max-time 300 --retry 5 --retry-delay 5 --fail 2>&1); then
            common_logger "The ${package} package was downloaded."
        else
            common_logger -e "The ${package} package could not be downloaded. Exiting."
            exit 1
        fi
    done

    common_logger "The packages are in ${dest_path}"

    common_logger "Downloading configuration files and assets."
    dest_path="${base_dest_folder}/wazuh-files"

    if [ -d "${dest_path}" ]; then
        eval "rm -f ${dest_path}/* ${debug}"
        eval "chmod 700 ${dest_path} ${debug}"
    else
        eval "mkdir -m700 -p ${dest_path} ${debug}"
    fi

    files_to_download=( "${wazuh_gpg_key}" "${filebeat_config_file}" "${filebeat_wazuh_template}" "${filebeat_wazuh_module}" )

    eval "cd ${dest_path}"
    for file in "${files_to_download[@]}"
    do
        common_logger -d "Downloading ${file}..."
        if output=$(common_curl -sSO ${file} --max-time 300 --retry 5 --retry-delay 5 --fail 2>&1); then
            common_logger "The resource ${file} was downloaded."
        else
            common_logger -e "The resource ${file} could not be downloaded. Exiting."
            exit 1
        fi
    done
    eval "cd - > /dev/null"

    eval "chmod 500 ${base_dest_folder} ${debug}"

    common_logger "The configuration files and assets are in ${dest_path}"

    common_logger "Creating wazuh-offline.tar.gz file."
    eval "tar -czf ${base_dest_folder}.tar.gz ${base_dest_folder} ${debug}"
    eval "chmod 700 ${base_dest_folder}.tar.gz ${debug}"
    eval "rm -rf ${base_dest_folder} ${debug}"

    common_logger "The file wazuh-offline.tar.gz has been created."
}

function offline_install() {
    if [ ! -f "${base_dest_folder}.tar.gz" ]; then
        common_logger -e "The file wazuh-offline.tar.gz does not exist."
        exit 1
    fi

    common_logger "Extracting wazuh-offline.tar.gz file."
    eval "tar -xzf ${base_dest_folder}.tar.gz -C / ${debug}"

    common_logger "Installing Wazuh packages."
    if [ "${sys_type}" == "yum" ]; then
        eval "yum install -y ${base_dest_folder}/wazuh-packages/* ${debug}"
    elif [ "${sys_type}" == "apt-get" ]; then
        eval "dpkg -i ${base_dest_folder}/wazuh-packages/* ${debug}"
    fi

    common_logger "Copying configuration files and assets."
    eval "cp ${base_dest_folder}/wazuh-files/* /etc/wazuh-indexer/ ${debug}"
    eval "cp ${base_dest_folder}/wazuh-files/filebeat.yml /etc/filebeat/ ${debug}"

    common_logger "Cleaning up temporary files."
    eval "rm -rf ${base_dest_folder} ${debug}"
    eval "rm -f ${base_dest_folder}.tar.gz ${debug}"

    common_logger "Offline installation completed."
}

# Export functions to be used in other scripts
export -f offline_download
export -f offline_install