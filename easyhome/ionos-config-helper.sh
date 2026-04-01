#!/bin/bash
#
# ionos-config-helper.sh — Create certbot IONOS credentials file
#
# Usage:
#   source ionos-config-helper.sh
#   create_ionos_credentials <api_key> <api_secret> [output_file]
#
# Output:
#   Generates /etc/letsencrypt/ionos.ini with proper format for certbot-dns-ionos

set -e

function create_ionos_credentials() {
    local api_key="${1}"
    local api_secret="${2}"
    local output_file="${3:-/etc/letsencrypt/ionos.ini}"

    if [[ -z "${api_key}" ]]; then
        echo "ERROR: API key required" >&2
        return 1
    fi

    if [[ -z "${api_secret}" ]]; then
        echo "ERROR: API secret required" >&2
        return 1
    fi

    # Ensure directory exists
    mkdir -p "$(dirname "${output_file}")"

    # Write config file with proper permissions
    cat > "${output_file}" <<EOF
dns_ionos_api_key = ${api_key}
dns_ionos_api_secret = ${api_secret}
EOF

    # Restrict permissions (certbot requirement for credential files)
    chmod 600 "${output_file}"

    echo "✓ IONOS credentials written to ${output_file}" >&2
}

function load_ionos_credentials_from_pass() {
    local api_key=""
    local api_secret=""

    # Try to load from pass CLI (preferred method)
    if command -v pass &> /dev/null; then
        if pass ionos/api-key &> /dev/null; then
            api_key=$(pass ionos/api-key)
        fi
        if pass ionos/api-secret &> /dev/null; then
            api_secret=$(pass ionos/api-secret)
        fi
    fi

    # Fallback to environment variables
    api_key="${api_key:-${IONOS_API_KEY}}"
    api_secret="${api_secret:-${IONOS_API_SECRET}}"

    if [[ -z "${api_key}" ]] || [[ -z "${api_secret}" ]]; then
        echo "ERROR: IONOS credentials not found in pass or env vars" >&2
        echo "       Set via: IONOS_API_KEY=xxx IONOS_API_SECRET=yyy" >&2
        echo "       Or: pass insert ionos/api-key && pass insert ionos/api-secret" >&2
        return 1
    fi

    create_ionos_credentials "${api_key}" "${api_secret}" "$1"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    load_ionos_credentials_from_pass "$@"
fi
