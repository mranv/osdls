#!/bin/bash

# Global variables
readonly wazuh_install_vesion="4.8.2"
readonly wazuh_version="4.8.2"
readonly filebeat_version="7.10.2"
readonly debug='> /dev/null 2>&1'
readonly logfile="/var/log/wazuh-installation.log"
readonly wazuh_install_log="${logfile}"
readonly wazuh_major="4.8"
readonly resources="https://packages.wazuh.com/${wazuh_major}"
readonly base_url="https://packages.wazuh.com/${wazuh_major}"

# Common functions

function common_logger() {

    now=$(date +'%d/%m/%Y %H:%M:%S')
    mtype="INFO:"
    debugLogger=
    nolog=
    if [ -n "${1}" ]; then
        while [ -n "${1}" ]; do
            case ${1} in
                "-e")
                    mtype="ERROR:"
                    shift 1
                    ;;
                "-w")
                    mtype="WARNING:"
                    shift 1
                    ;;
                "-d")
                    debugLogger=1
                    mtype="DEBUG:"
                    shift 1
                    ;;
                "-nl")
                    nolog=1
                    shift 1
                    ;;
                *)
                    message="${1}"
                    shift 1
                    ;;
            esac
        done
    fi

    if [ -z "${debugLogger}" ] || { [ -n "${debugLogger}" ] && [ -n "${debugEnabled}" ]; }; then
        if [ "$EUID" -eq 0 ] && [ -z "${nolog}" ]; then
            printf "%s\n" "${now} ${mtype} ${message}" | tee -a ${logfile}
        else
            printf "%b\n" "${now} ${mtype} ${message}"
        fi
    fi

}

function common_checkRoot() {

    common_logger -d "Checking root permissions."
    if [ "$EUID" -ne 0 ]; then
        common_logger -e "This script must be run as root."
        exit 1;
    fi

    common_logger -d "Checking sudo package."
    if ! command -v sudo > /dev/null; then 
        common_logger -e "The sudo package is not installed and it is necessary for the installation."
        exit 1;
    fi
}

function common_checkInstalled() {

    common_logger -d "Checking Wazuh installation."
    wazuh_installed=""
    indexer_installed=""
    filebeat_installed=""
    dashboard_installed=""

    if [ "${sys_type}" == "yum" ]; then
        wazuh_installed=$(yum list installed 2>/dev/null | grep wazuh-manager)
    elif [ "${sys_type}" == "apt-get" ]; then
        wazuh_installed=$(apt list --installed  2>/dev/null | grep wazuh-manager)
    fi

    if [ -d "/var/ossec" ]; then
        common_logger -d "There are Wazuh remaining files."
        wazuh_remaining_files=1
    fi

    if [ "${sys_type}" == "yum" ]; then
        indexer_installed=$(yum list installed 2>/dev/null | grep wazuh-indexer)
    elif [ "${sys_type}" == "apt-get" ]; then
        indexer_installed=$(apt list --installed 2>/dev/null | grep wazuh-indexer)
    fi

    if [ -d "/var/lib/wazuh-indexer/" ] || [ -d "/usr/share/wazuh-indexer" ] || [ -d "/etc/wazuh-indexer" ]; then
        common_logger -d "There are Wazuh indexer remaining files."
        indexer_remaining_files=1
    fi

    if [ "${sys_type}" == "yum" ]; then
        filebeat_installed=$(yum list installed 2>/dev/null | grep filebeat)
    elif [ "${sys_type}" == "apt-get" ]; then
        filebeat_installed=$(apt list --installed  2>/dev/null | grep filebeat)
    fi

    if [ -d "/var/lib/filebeat/" ] || [ -d "/usr/share/filebeat" ] || [ -d "/etc/filebeat" ]; then
        common_logger -d "There are Filebeat remaining files."
        filebeat_remaining_files=1
    fi

    if [ "${sys_type}" == "yum" ]; then
        dashboard_installed=$(yum list installed 2>/dev/null | grep wazuh-dashboard)
    elif [ "${sys_type}" == "apt-get" ]; then
        dashboard_installed=$(apt list --installed  2>/dev/null | grep wazuh-dashboard)
    fi

    if [ -d "/var/lib/wazuh-dashboard/" ] || [ -d "/usr/share/wazuh-dashboard" ] || [ -d "/etc/wazuh-dashboard" ] || [ -d "/run/wazuh-dashboard/" ]; then
        common_logger -d "There are Wazuh dashboard remaining files."
        dashboard_remaining_files=1
    fi

}

function common_checkSystem() {

    if [ -n "$(command -v yum)" ]; then
        sys_type="yum"
        sep="-"
        common_logger -d "YUM package manager will be used."
    elif [ -n "$(command -v apt-get)" ]; then
        sys_type="apt-get"
        sep="="
        common_logger -d "APT package manager will be used."
    else
        common_logger -e "Couldn't find type of system"
        exit 1
    fi

}

function common_checkAptLock() {

    attempt=0
    seconds=30
    max_attempts=10

    while fuser "${apt_lockfile}" >/dev/null 2>&1 && [ "${attempt}" -lt "${max_attempts}" ]; do
        attempt=$((attempt+1))
        common_logger "Another process is using APT. Waiting for it to release the lock. Next retry in ${seconds} seconds (${attempt}/${max_attempts})"
        sleep "${seconds}"
    done

}

function common_checkYumLock() {

    attempt=0
    seconds=30
    max_attempts=10

    while [ -f "${yum_lockfile}" ] && [ "${attempt}" -lt "${max_attempts}" ]; do
        attempt=$((attempt+1))
        common_logger "Another process is using YUM. Waiting for it to release the lock. Next retry in ${seconds} seconds (${attempt}/${max_attempts})"
        sleep "${seconds}"
    done

}

function common_curl() {

    if [ -n "${curl_has_connrefused}" ]; then
        eval "curl $@ --retry-connrefused"
        e_code="${PIPESTATUS[0]}"
    else
        retries=0
        eval "curl $@"
        e_code="${PIPESTATUS[0]}"
        while [ "${e_code}" -eq 7 ] && [ "${retries}" -ne 12 ]; do
            retries=$((retries+1))
            sleep 5
            eval "curl $@"
            e_code="${PIPESTATUS[0]}"
        done
    fi
    return "${e_code}"

}

# Add more common utility functions as needed

# Export functions to be used in other scripts
export -f common_logger
export -f common_checkRoot
export -f common_checkInstalled
export -f common_checkSystem
export -f common_checkAptLock
export -f common_checkYumLock
export -f common_curl