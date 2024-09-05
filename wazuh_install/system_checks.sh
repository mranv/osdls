#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
min_ram_gb=3700  # Minimum RAM in MB
min_cpu_cores=2

# System check functions

function checks_arch() {
    common_logger -d "Checking system architecture."
    arch=$(uname -m)

    if [ "${arch}" != "x86_64" ]; then
        common_logger -e "Incompatible system. This script must be run on a 64-bit system."
        exit 1
    fi
}

function checks_dist() {
    common_logger -d "Checking system distribution."
    if [ -f "/etc/os-release" ]; then
        . /etc/os-release
        DIST_NAME="${ID}"
        DIST_VER="${VERSION_ID}"
    elif type lsb_release >/dev/null 2>&1; then
        DIST_NAME=$(lsb_release -si)
        DIST_VER=$(lsb_release -sr)
    else
        common_logger -e "Unable to determine the system distribution."
        exit 1
    fi

    common_logger -d "Detected distribution: ${DIST_NAME} ${DIST_VER}"

    case "${DIST_NAME}" in
        "rhel"|"centos")
            if [[ "${DIST_VER}" != "7" && "${DIST_VER}" != "8" && "${DIST_VER}" != "9" ]]; then
                common_logger -e "Incompatible distribution version. Supported versions are 7, 8, and 9."
                exit 1
            fi
            ;;
        "ubuntu")
            if [[ "${DIST_VER}" != "16.04" && "${DIST_VER}" != "18.04" && "${DIST_VER}" != "20.04" && "${DIST_VER}" != "22.04" ]]; then
                common_logger -e "Incompatible distribution version. Supported versions are 16.04, 18.04, 20.04, and 22.04."
                exit 1
            fi
            ;;
        *)
            common_logger -e "Unsupported distribution: ${DIST_NAME}"
            exit 1
            ;;
    esac
}

function checks_health() {
    common_logger -d "Checking system health."
    
    # Check CPU cores
    cpu_cores=$(nproc)
    if [ "${cpu_cores}" -lt "${min_cpu_cores}" ]; then
        common_logger -e "The system does not meet the minimum CPU requirements. ${min_cpu_cores} cores required."
        exit 1
    fi

    # Check RAM
    ram_mb=$(free -m | awk '/^Mem:/{print $2}')
    if [ "${ram_mb}" -lt "${min_ram_gb}" ]; then
        common_logger -e "The system does not meet the minimum RAM requirements. ${min_ram_gb}MB required."
        exit 1
    fi

    common_logger -d "System health check passed."
}

function checks_ports() {
    common_logger -d "Checking if required ports are available."
    local ports=("$@")
    for port in "${ports[@]}"; do
        if lsof -i:${port} > /dev/null 2>&1; then
            common_logger -e "Port ${port} is already in use. Please free this port and try again."
            exit 1
        fi
    done
    common_logger -d "All required ports are available."
}

function checks_firewall() {
    common_logger -d "Checking firewall status."
    if command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state >/dev/null 2>&1; then
            common_logger -w "Firewall is active. Please ensure required ports are open."
            # Here you can add logic to automatically open required ports if needed
        fi
    elif command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            common_logger -w "UFW firewall is active. Please ensure required ports are open."
            # Here you can add logic to automatically open required ports if needed
        fi
    else
        common_logger -d "No supported firewall detected."
    fi
}

function checks_previousInstallation() {
    common_logger -d "Checking for previous Wazuh installations."
    local components=("wazuh-manager" "wazuh-indexer" "wazuh-dashboard" "filebeat")
    for component in "${components[@]}"; do
        if common_checkPackage "${component}"; then
            common_logger -w "Previous installation of ${component} found."
            if [ -z "${overwrite}" ]; then
                common_logger -e "Wazuh components are already installed. Use -o|--overwrite to overwrite the current installation."
                exit 1
            fi
        fi
    done
}

function checks_dependencies() {
    common_logger -d "Checking for required dependencies."
    local dependencies=("curl" "openssl" "tar")
    for dep in "${dependencies[@]}"; do
        if ! command -v ${dep} >/dev/null 2>&1; then
            common_logger -e "Dependency ${dep} is not installed. Please install it and try again."
            exit 1
        fi
    done
    common_logger -d "All required dependencies are installed."
}

# Add more system check functions as needed

# Main check function to run all checks
function run_checks() {
    checks_arch
    checks_dist
    checks_health
    checks_ports "${wazuh_ports[@]}"
    checks_firewall
    checks_previousInstallation
    checks_dependencies
    common_logger "All system checks passed successfully."
}

# Export functions to be used in other scripts
export -f checks_arch
export -f checks_dist
export -f checks_health
export -f checks_ports
export -f checks_firewall
export -f checks_previousInstallation
export -f checks_dependencies
export -f run_checks