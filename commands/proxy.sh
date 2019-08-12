#!/bin/bash
function __easy_command_proxy_help {
 echo "usage:"
 echo "    easy proxy sh"
 echo "    easy proxy log"
 echo "    easy proxy build"
 echo "    easy proxy new"
 echo "    easy proxy status"
 echo "    easy proxy stop"
 echo "    easy proxy destroy"
 echo "    easy proxy restart"
 echo "    easy proxy reload"
 echo "    easy proxy certbot"
 echo "    easy proxy help"
}

function __easy_command_proxy {
 if [[ -z "${EASY_DIR}" ]]; then
  echo "Invalid EASY_DIR"
  return 1
 fi
 if [[ "help" == "$2" ]]; then
   __easy_command_proxy_help
   return $?
 fi
 if [[ "certbot" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  local EMAIL
  local DOMAIN
  read -p 'Email: ' EMAIL
  read -p 'Domain: ' DOMAIN
  if [[ -z "${EMAIL}" ]]; then
   echo "Invalid Email."
   return 1
  fi
  if [[ -z "${DOMAIN}" ]]; then
   echo "Invalid Domain."
   return 1
  fi
  docker exec -it "${EASY_PROXY}" sudo certbot --email ${EMAIL} --agree-tos --manual-public-ip-logging-ok certonly --manual --preferred-challenges dns -d "${DOMAIN},*.${DOMAIN}"
  return $?
 fi
 if [[ "reload" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  docker exec -it "${EASY_PROXY}" sudo nginx -c /usr/local/share/easy/nginx.conf -s reload
  return $?
 fi
 if [[ "build" == "$2" ]]; then
  docker build "${EASY_DIR}" -t ethiclab/nginx-easy
  return $?
 fi
 if [[ "new" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
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
   docker exec -it "${EASY_PROXY}" /usr/local/share/easy/add_subdomain_http $4 $5 $6
  elif [[ "https" == "$3" ]]; then
   docker exec -it "${EASY_PROXY}" /usr/local/share/easy/add_subdomain_https $4 $5 $6
  else
   echo "Invalid protocol $3"
   return 1
  fi
  return $?
 fi
 if [[ "sh" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  docker exec -it "${EASY_PROXY}" bash
 fi
 if [[ "log" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  docker logs -f "${EASY_PROXY}" 
  return $?
 fi
 if [[ "destroy" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  docker stop "${EASY_PROXY}" 
  docker rm "${EASY_PROXY}" 
  return $?
 fi
 if [[ "stop" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  docker stop "${EASY_PROXY}" 
  return $?
 fi
 if [[ "restart" == "$2" ]]; then
  local EASY_PROXY=$(easy proxy status)
  if [[ -z "${EASY_PROXY}" ]]; then
   echo "Proxy is not running."
   return 1
  fi
  docker restart "${EASY_PROXY}" 
  return $?
 fi
 if [[ "status" == "$2" ]]; then
  local TMP=$(for container in $(docker ps -q); do docker container port $container 80/tcp 1>/dev/null 2>/dev/null && echo $container; done)
  if [[ ! -z "${TMP}" ]]; then
   echo "${TMP}"
  fi 
  return 0
 fi
 if [[ -z "$2" ]]; then
  __easy_command_proxy_default
  return $?
 else
  __easy_command_proxy_help
  return 1
 fi
}

function __easy_command_proxy_default {
 local EASY_PROXY=$(easy proxy status)
 if [[ ! -z "${EASY_PROXY}" ]]; then
  echo "There is another docker container running with port 80 bound. Proxy could be already running as ${EASY_PROXY}"
  return 1
 fi
 if [[ -z "${EASY_LETSENCRYPT_DIR}" ]]; then
  echo "Invalid EASY_LETSENCRYPT_DIR"
  return 1
 fi
 docker run -d \
 -v ${EASY_DOMAINS_DIR}:/domains \
 -v ${EASY_LETSENCRYPT_DIR}:/etc/letsencrypt \
 -v ${EASY_DIR}/easyhome:/usr/local/share/easy \
 -p 80:80 \
 -p 443:443 \
 -t ethiclab/nginx-easy
}
