#!/bin/bash

# Source all components
source common_utils.sh
source password_management.sh
source certificate_management.sh
source system_checks.sh
source installations/wazuh_server_install.sh
source installations/wazuh_indexer_install.sh
source installations/wazuh_dashboard_install.sh
source installations/filebeat_install.sh
source configurations/wazuh_server_config.sh
source configurations/wazuh_indexer_config.sh
source configurations/wazuh_dashboard_config.sh
source configurations/filebeat_config.sh
source offline_install.sh

function main() {
    umask 177

    if [ -z "${1}" ]; then
        getHelp
    fi

    while [ -n "${1}" ]
    do
        case "${1}" in
            "-a"|"--all-in-one")
                AIO=1
                shift 1
                ;;
            "-c"|"--config-file")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <path-to-config-yml> after -c|--config-file"
                    getHelp
                    exit 1
                fi
                file_conf=1
                config_file="${2}"
                shift 2
                ;;
            "-fd"|"--force-install-dashboard")
                force=1
                shift 1
                ;;
            "-g"|"--generate-config-files")
                configurations=1
                shift 1
                ;;
            "-h"|"--help")
                getHelp
                ;;
            "-i"|"--ignore-check")
                ignore=1
                shift 1
                ;;
            "-o"|"--overwrite")
                overwrite=1
                shift 1
                ;;
            "-p"|"--port")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <port> after -p|--port"
                    getHelp
                    exit 1
                fi
                port_specified=1
                port_number="${2}"
                shift 2
                ;;
            "-s"|"--start-cluster")
                start_indexer_cluster=1
                shift 1
                ;;
            "-t"|"--tar")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <path-to-certs-tar> after -t|--tar"
                    getHelp
                    exit 1
                fi
                tar_conf=1
                tar_file="${2}"
                shift 2
                ;;
            "-u"|"--uninstall")
                uninstall=1
                shift 1
                ;;
            "-v"|"--verbose")
                debugEnabled=1
                debug="2>&1 | tee -a ${logfile}"
                shift 1
                ;;
            "-V"|"--version")
                showVersion=1
                shift 1
                ;;
            "-wd"|"--wazuh-dashboard")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <node-name> after -wd|---wazuh-dashboard"
                    getHelp
                    exit 1
                fi
                dashboard=1
                dashname="${2}"
                shift 2
                ;;
            "-wi"|"--wazuh-indexer")
                if [ -z "${2}" ]; then
                    common_logger -e "Arguments contain errors. Probably missing <node-name> after -wi|--wazuh-indexer."
                    getHelp
                    exit 1
                fi
                indexer=1
                indxname="${2}"
                shift 2
                ;;
            "-ws"|"--wazuh-server")
                if [ -z "${2}" ]; then
                    common_logger -e "Error on arguments. Probably missing <node-name> after -ws|--wazuh-server"
                    getHelp
                    exit 1
                fi
                wazuh=1
                winame="${2}"
                shift 2
                ;;
            "-dw"|"--download-wazuh")
                if [ "${2}" != "deb" ] && [ "${2}" != "rpm" ]; then
                    common_logger -e "Error on arguments. Probably missing <deb|rpm> after -dw|--download-wazuh"
                    getHelp
                    exit 1
                fi
                download=1
                package_type="${2}"
                shift 2
                ;;
            *)
                echo "Unknown option: ${1}"
                getHelp
        esac
    done

    if [ -z "${download}" ] && [ -z "${showVersion}" ]; then
        common_checkRoot
    fi

    common_logger "Starting Wazuh installation assistant. Wazuh version: ${wazuh_version}"
    common_logger "Verbose logging redirected to ${logfile}"

    if [ -z "${download}" ]; then
        checks_arguments
        checks_health
    fi

    if [ -n "${configurations}" ]; then
        common_logger "--- Configuration files ---"
        installCommon_createInstallFiles
    fi

    if [ -n "${AIO}" ]; then
        install_all_in_one
    fi

    if [ -n "${indexer}" ]; then
        install_wazuh_indexer
    fi

    if [ -n "${wazuh}" ]; then
        install_wazuh_server
    fi

    if [ -n "${dashboard}" ]; then
        install_wazuh_dashboard
    fi

    if [ -n "${start_indexer_cluster}" ]; then
        start_indexer_cluster
    fi

    if [ -n "${download}" ]; then
        offline_download
    fi

    if [ -n "${uninstall}" ]; then
        uninstall_all
    fi

    common_logger "Installation finished."
}

function getHelp() {
    echo -e ""
    echo -e "Usage: $0 [OPTIONS]"
    echo -e ""
    echo -e "    -a,  --all-in-one          [All-In-One] Install Wazuh manager, Wazuh indexer, and Wazuh dashboard."
    echo -e "    -c,  --config-file         [Config] Use custom config file."
    echo -e "    -dw, --download-wazuh      [Download] Download Wazuh packages for air-gapped installation."
    echo -e "    -fd, --force-install-dashboard         [Dashboard] Force Wazuh dashboard installation."
    echo -e "    -g,  --generate-config-files        [Config] Generate config files."
    echo -e "    -h,  --help                Display this help and exit."
    echo -e "    -i,  --ignore-check        Ignore the check for system compatibility."
    echo -e "    -o,  --overwrite           [Overwrite] Overwrite the existing installation."
    echo -e "    -p,  --port                [Port] Specify Wazuh web user interface port."
    echo -e "    -s,  --start-cluster       [Cluster] Start Wazuh indexer cluster."
    echo -e "    -t,  --tar                 [Tar] Use custom tar file with certificates."
    echo -e "    -u,  --uninstall           Uninstall Wazuh components."
    echo -e "    -v,  --verbose             Show verbose output."
    echo -e "    -V,  --version             Display Wazuh version."
    echo -e "    -wd, --wazuh-dashboard     [Dashboard] Install Wazuh dashboard."
    echo -e "    -wi, --wazuh-indexer       [Indexer] Install Wazuh indexer."
    echo -e "    -ws, --wazuh-server        [Manager] Install Wazuh manager."
    exit 1
}

main "$@"