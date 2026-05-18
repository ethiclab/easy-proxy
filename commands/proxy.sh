#!/bin/bash

#######################################################################################
# BEGIN: utilities from https://github.com/montoyaedu/Trish/blob/master/test_tools.sh #
#######################################################################################

CAT=$(which cat)

function read_input {
    "${CAT}" -
}

function debug {
    >&2 echo "$@"
}

function is {
    local actual
    actual=$(read_input)
    local expected="$*"
    if [ "${actual}" == "${expected}" ]; then
        return 0
    else
        debug "expected '${expected}' but got '${actual}'"
        return 1
    fi
}

#####################################################################################
# END: utilities from https://github.com/montoyaedu/Trish/blob/master/test_tools.sh #
#####################################################################################

# The proxy container is identified by a fixed name, never by a state file.
# `npm install -g` puts the CLI under a root-owned path, so writing runtime
# state (the old `.id` file) next to the code failed for non-root users.
# Docker itself is the single source of truth — see issue #5.
EASY_PROXY_NAME='easy-proxy'

function __easy_command_proxy_help {
 echo "usage:"
 echo "    easy proxy create"
 echo "    easy proxy sh"
 echo "    easy proxy log"
 echo "    easy proxy build"
 echo "    easy proxy new"
 echo "    easy proxy id"
 echo "    easy proxy status"
 echo "    easy proxy doctor"
 echo "    easy proxy start"
 echo "    easy proxy stop"
 echo "    easy proxy destroy"
 echo "    easy proxy restart"
 echo "    easy proxy reload"
 echo "    easy proxy certbot"
 echo "    easy proxy certbot-ionos <domain>"
 echo "    easy proxy rfc2136"
 echo "    easy proxy help"
}

function __easy_command_proxy {
 if [[ -z "${EASY_DIR}" ]]; then
  echo "Invalid EASY_DIR"
  return 1
 fi
 if [[ "create" == "$2" ]]; then
   __easy_command_proxy_create
   return $?
 fi
 if [[ "help" == "$2" ]]; then
   __easy_command_proxy_help
   return $?
 fi
 if [[ "rfc2136" == "$2" ]]; then
  if [[ -z "${EASY_LETSENCRYPT_EMAIL}" ]]; then
   echo "Invalid Email. Set environment variable EASY_LETSENCRYPT_EMAIL"
   return 1
  fi
  if [[ -z "${EASY_LETSENCRYPT_DOMAIN}" ]]; then
   echo "Invalid Domain. Set environment variable EASY_LETSENCRYPT_DOMAIN"
   return 1
  fi
  docker run --rm -i --name certfbot -v "${EASY_LETSENCRYPT_DIR}:/etc/letsencrypt" certbot/dns-rfc2136 certonly --renew-by-default --dns-rfc2136-credentials /etc/letsencrypt/secret.txt --dns-rfc2136 -d "${EASY_LETSENCRYPT_DOMAIN},*.${EASY_LETSENCRYPT_DOMAIN}" --agree-tos
  return $?
 fi
 if [[ "certbot" == "$2" ]]; then
  if [[ -z "$(easy proxy status)" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  if [[ -z "${EASY_LETSENCRYPT_EMAIL}" ]]; then
   echo "Invalid Email. Set environment variable EASY_LETSENCRYPT_EMAIL"
   return 1
  fi
  if [[ -z "${EASY_LETSENCRYPT_DOMAIN}" ]]; then
   echo "Invalid Domain. Set environment variable EASY_LETSENCRYPT_DOMAIN"
   return 1
  fi
  docker exec -it "${EASY_PROXY_NAME}" sudo certbot --email "${EASY_LETSENCRYPT_EMAIL}" --agree-tos --manual-public-ip-logging-ok certonly --manual --preferred-challenges dns -d "${EASY_LETSENCRYPT_DOMAIN},*.${EASY_LETSENCRYPT_DOMAIN}"
  return $?
 fi
 if [[ "certbot-ionos" == "$2" ]]; then
  if [[ -z "$(easy proxy status)" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  if [[ -z "${EASY_LETSENCRYPT_EMAIL}" ]]; then
   echo "Invalid Email. Set environment variable EASY_LETSENCRYPT_EMAIL"
   return 1
  fi
  if [[ -z "$3" ]]; then
   echo "Domain required: easy proxy certbot-ionos <domain>"
   echo "Example: easy proxy certbot-ionos ethiclab.it"
   return 1
  fi

  local domain="$3"
  local api_key="${IONOS_API_KEY}"
  local api_secret="${IONOS_API_SECRET}"

  # Try to load from pass if credentials not in env
  if [[ -z "${api_key}" ]] && command -v pass &> /dev/null; then
   if pass ionos/api-key &> /dev/null; then
    api_key=$(pass ionos/api-key)
   fi
  fi
  if [[ -z "${api_secret}" ]] && command -v pass &> /dev/null; then
   if pass ionos/api-secret &> /dev/null; then
    api_secret=$(pass ionos/api-secret)
   fi
  fi

  if [[ -z "${api_key}" ]] || [[ -z "${api_secret}" ]]; then
   echo "ERROR: IONOS API credentials not found"
   echo "Set via environment: IONOS_API_KEY=xxx IONOS_API_SECRET=yyy"
   echo "Or use pass CLI: pass insert ionos/api-key && pass insert ionos/api-secret"
   return 1
  fi

  # Create credentials file in container
  docker exec "${EASY_PROXY_NAME}" /bin/sh -c "cat > /etc/letsencrypt/ionos.ini <<'EOF'
dns_ionos_api_key = ${api_key}
dns_ionos_api_secret = ${api_secret}
EOF
chmod 600 /etc/letsencrypt/ionos.ini"

  # Generate certificate via DNS-01 challenge with IONOS plugin
  echo "Generating certificate for ${domain} and *.${domain} via IONOS DNS..."
  docker exec "${EASY_PROXY_NAME}" certbot certonly \
   --non-interactive \
   --agree-tos \
   --email "${EASY_LETSENCRYPT_EMAIL}" \
   --dns-ionos \
   --dns-ionos-credentials /etc/letsencrypt/ionos.ini \
   -d "${domain}" -d "*.${domain}"

  return $?
 fi
 if [[ "reload" == "$2" ]]; then
  if [[ -z "$(easy proxy status)" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  docker exec "${EASY_PROXY_NAME}" nginx -c /usr/local/share/easy/nginx.conf -s reload
  return $?
 fi
 if [[ "build" == "$2" ]]; then
  docker build "${EASY_DIR}" -t ethiclab/nginx-easy
  return $?
 fi
 if [[ "new" == "$2" ]]; then
  if [[ -z "$(easy proxy status)" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  if [[ "$#" -ne 6 ]]; then
   echo "Too few arguments"
   echo "Usage:"
   echo "    easy proxy new [http|https] <fully qualified servername> <domain> <http target server>"
   echo "For instance:"
   echo "    easy proxy new http myserver.mydomain.com mydomain.com http://someserver:someport"
   return 1
  fi
  if [[ "http" == "$3" ]]; then
   docker exec "${EASY_PROXY_NAME}" /usr/local/share/easy/add_subdomain_http "$4" "$5" "$6"
  elif [[ "https" == "$3" ]]; then
   docker exec "${EASY_PROXY_NAME}" /usr/local/share/easy/add_subdomain_https "$4" "$5" "$6"
  else
   echo "Invalid protocol $3"
   return 1
  fi
  return $?
 fi
 if [[ "sh" == "$2" ]]; then
  docker exec -it "${EASY_PROXY_NAME}" bash
  return $?
 fi
 if [[ "log" == "$2" ]]; then
  docker logs -f "${EASY_PROXY_NAME}"
  return $?
 fi
 if [[ "destroy" == "$2" ]]; then
  docker stop "${EASY_PROXY_NAME}"
  docker rm "${EASY_PROXY_NAME}"
  return $?
 fi
 if [[ "start" == "$2" ]]; then
  docker start "${EASY_PROXY_NAME}"
  return $?
 fi
 if [[ "stop" == "$2" ]]; then
  docker stop "${EASY_PROXY_NAME}"
  return $?
 fi
 if [[ "restart" == "$2" ]]; then
  docker restart "${EASY_PROXY_NAME}"
  return $?
 fi
 if [[ "id" == "$2" ]]; then
  docker ps -aq -f "name=^${EASY_PROXY_NAME}$" 2>/dev/null
  return $?
 fi
 if [[ "status" == "$2" ]]; then
  docker ps -q -f "name=^${EASY_PROXY_NAME}$" 2>/dev/null
  return $?
 fi
 if [[ "doctor" == "$2" ]]; then
  __easy_command_proxy_doctor
  return $?
 fi
 if [[ -z "$2" ]]; then
  __easy_command_proxy_default
  return $?
 else
  __easy_command_proxy_help
  return 1
 fi
}

function __easy_command_proxy_create {
 if [[ -n "$(easy proxy id)" ]]; then
  echo "There is already an easy proxy instance named ${EASY_PROXY_NAME}"
  return 1
 fi
 if [[ -z "${EASY_LETSENCRYPT_DIR}" ]]; then
  echo "Invalid EASY_LETSENCRYPT_DIR"
  return 1
 fi
 docker run -d \
 --name "${EASY_PROXY_NAME}" \
 -v "${EASY_DOMAINS_DIR}:/domains" \
 -v "${EASY_LETSENCRYPT_DIR}:/etc/letsencrypt" \
 -v "${EASY_DIR}/easyhome:/usr/local/share/easy" \
 -p 80:80 \
 -p 443:443 \
 -t ethiclab/nginx-easy
 return $?
}

# Read-only pre-flight diagnostic: static vhost analysis (host-side) plus,
# when the proxy is running, the nginx config test and the network list.
# Exits non-zero only when nginx -t fails (a definite startup blocker).
function __easy_command_proxy_doctor {
 echo "easy proxy doctor — pre-flight check"
 echo
 local warnings=0

 # vhost configs — static analysis, host-side (no Docker needed)
 echo "vhost configs (${EASY_DOMAINS_DIR}):"
 local confs
 confs=$(find "${EASY_DOMAINS_DIR}" -type f -name '*.conf' 2>/dev/null | sort)
 if [[ -z "${confs}" ]]; then
  echo "  no vhost files found"
 else
  echo "  $(printf '%s\n' "${confs}" | wc -l | tr -d ' ') vhost file(s)"
  local conf
  while IFS= read -r conf; do
   if grep -qE '^[[:space:]]*upstream[[:space:]]' "${conf}"; then
    echo "  WARN ${conf}"
    echo "       static 'upstream {}' block — resolved at nginx startup; one"
    echo "       unresolvable host blocks every site. Convert to a variable:"
    echo "       set \$u <host>; proxy_pass http://\$u;"
    warnings=$((warnings + 1))
   fi
   if grep -qE 'listen[^;]*http2' "${conf}"; then
    echo "  WARN ${conf}"
    echo "       deprecated 'listen ... http2' — use the 'http2 on;' directive"
    warnings=$((warnings + 1))
   fi
  done <<< "${confs}"
 fi
 echo

 # runtime checks — need the running container
 local proxy_running
 proxy_running=$(easy proxy status)

 echo "nginx config test:"
 local nginx_failed=0
 if [[ -z "${proxy_running}" ]]; then
  echo "  skipped — proxy not running ('easy proxy create' first)"
 elif docker exec "${EASY_PROXY_NAME}" nginx -t -c /usr/local/share/easy/nginx.conf >/dev/null 2>&1; then
  echo "  PASS"
 else
  echo "  FAIL — details: docker exec ${EASY_PROXY_NAME} nginx -t"
  nginx_failed=1
 fi
 echo

 echo "proxy networks:"
 if [[ -z "${proxy_running}" ]]; then
  echo "  skipped — proxy not running"
 else
  local nets
  nets=$(docker inspect "${EASY_PROXY_NAME}" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null)
  echo "  ${nets:-(none)}"
 fi
 echo

 echo "summary: ${warnings} warning(s)"
 return "${nginx_failed}"
}

function __easy_command_proxy_default {
  __easy_command_proxy_help
  return 1
}
