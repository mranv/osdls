#!/bin/bash

# Source common utility functions
source common_utils.sh

# Global variables
users=( admin kibanaserver kibanaro logstash readall snapshotrestore )
api_users=( wazuh wazuh-wui )

# Password management functions

function passwords_generatePassword() {
    if [ -n "${nuser}" ]; then
        common_logger -d "Generating random password for ${nuser}."
        pass=$(< /dev/urandom tr -dc "A-Za-z0-9.*+?" | head -c 64 | sed 's/[^a-zA-Z0-9]//g' | head -c 32 || echo "")
        if [ -n "${pass}" ]; then
            common_logger -d "Random password generated successfully."
        else
            common_logger -e "Could not generate random password."
            exit 1
        fi
    else
        common_logger -d "Generating random passwords for all users."
        for i in "${!users[@]}"; do
            passwords[i]=$(< /dev/urandom tr -dc "A-Za-z0-9.*+?" | head -c 64 | sed 's/[^a-zA-Z0-9]//g' | head -c 32 || echo "")
            if [ -z "${passwords[i]}" ]; then
                common_logger -e "Could not generate random password for ${users[i]}."
                exit 1
            fi
        done
        for i in "${!api_users[@]}"; do
            api_passwords[i]=$(< /dev/urandom tr -dc "A-Za-z0-9.*+?" | head -c 64 | sed 's/[^a-zA-Z0-9]//g' | head -c 32 || echo "")
            if [ -z "${api_passwords[i]}" ]; then
                common_logger -e "Could not generate random password for ${api_users[i]}."
                exit 1
            fi
        done
        common_logger -d "Random passwords generated successfully."
    fi
}

function passwords_readUsers() {
    common_logger -d "Reading users from internal_users.yml"
    if [ -f "/etc/wazuh-indexer/opensearch-security/internal_users.yml" ]; then
        while IFS= read -r line; do
            if [[ $line == *":"* ]] && [[ $line != *"#"* ]]; then
                user=$(echo $line | cut -d ":" -f 1)
                users+=("$user")
            fi
        done < "/etc/wazuh-indexer/opensearch-security/internal_users.yml"
    else
        common_logger -e "internal_users.yml file not found."
        exit 1
    fi
}

function passwords_getApiToken() {
    common_logger -d "Getting API token."
    TOKEN_API=$(curl -s -u "${adminUser}":"${adminPassword}" -k -X GET "https://localhost:55000/security/user/authenticate" -H "Content-Type: application/json" | python -m json.tool 2> /dev/null | grep "token" | cut -d ":" -f 2 | sed 's/[", ]//g')
    if [ -n "${TOKEN_API}" ]; then
        common_logger -d "API token acquired successfully."
    else
        common_logger -e "Could not get API token."
        exit 1
    fi
}

function passwords_getApiUsers() {
    common_logger -d "Getting API users."
    api_users=()
    while IFS= read -r user; do
        api_users+=("$user")
    done < <(common_curl -s -k -X GET -H "Authorization: Bearer $TOKEN_API" -H "Content-Type: application/json" "https://localhost:55000/security/users" | grep -o '"username":"[^"]*' | cut -d'"' -f4)
    if [ ${#api_users[@]} -eq 0 ]; then
        common_logger -e "No API users found."
        exit 1
    fi
    common_logger -d "API users retrieved successfully."
}

function passwords_createBackUp() {
    common_logger -d "Creating password backup."
    if [ ! -d "/etc/wazuh-indexer/backup" ]; then
        mkdir "/etc/wazuh-indexer/backup"
    fi
    if [ -f "/etc/wazuh-indexer/opensearch-security/internal_users.yml" ]; then
        cp "/etc/wazuh-indexer/opensearch-security/internal_users.yml" "/etc/wazuh-indexer/backup/internal_users.yml.${date_timestamp}"
        common_logger -d "Backup created successfully."
    else
        common_logger -e "Could not create backup: internal_users.yml not found."
        exit 1
    fi
}

function passwords_changePassword() {
    if [ -n "${nuser}" ]; then
        common_logger -d "Changing password for user ${nuser}."
        if grep -q "${nuser}:" /etc/wazuh-indexer/opensearch-security/internal_users.yml; then
            sed -i "s/\(${nuser}:\)/\1\n  hash: \"${pass}\"/" /etc/wazuh-indexer/opensearch-security/internal_users.yml
            common_logger -d "Password changed successfully for user ${nuser}."
        else
            common_logger -e "User ${nuser} not found in internal_users.yml"
            exit 1
        fi
    else
        common_logger -d "Changing passwords for all users."
        for i in "${!users[@]}"; do
            if grep -q "${users[i]}:" /etc/wazuh-indexer/opensearch-security/internal_users.yml; then
                sed -i "s/\(${users[i]}:\)/\1\n  hash: \"${passwords[i]}\"/" /etc/wazuh-indexer/opensearch-security/internal_users.yml
            else
                common_logger -e "User ${users[i]} not found in internal_users.yml"
            fi
        done
        common_logger -d "Passwords changed successfully for all users."
    fi
}

# Add more password management functions as needed

# Export functions to be used in other scripts
export -f passwords_generatePassword
export -f passwords_readUsers
export -f passwords_getApiToken
export -f passwords_getApiUsers
export -f passwords_createBackUp
export -f passwords_changePassword