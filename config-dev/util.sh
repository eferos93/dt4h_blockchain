#!/bin/bash

# Standard fabric paths
export FABRIC_HOME=${PWD}
export FABRIC_CFG_PATH=${FABRIC_HOME}/config
export BINPATH=${FABRIC_HOME}/bin
export FABRIC_CA_CFG_PATH=${FABRIC_HOME}/config
export FABRIC_CA_PATH=${FABRIC_HOME}/organizations/fabric-ca
export PATH=$PATH:${BINPATH}
export COMPOSE_PROJECT_NAME=fabric
export DOCKER_HOME=${FABRIC_HOME}/docker
export LOG_PATH=${FABRIC_HOME}/logs

# Application Path
export APP_PATH=${FABRIC_HOME}/application-typescript/

# API Paths
export FABRIC_PEER_API=${FABRIC_HOME}/api/peerAPI
export FABRIC_CA_API=${FABRIC_HOME}/api/caAPI
export FABRIC_TOOLS_API=${FABRIC_HOME}/api/toolsAPI

# Fabric Version of binaries
export CA_TAG=1.5.1
export FABRIC_TAG=2.2.5

# Helper Functions 

# Colours
RED='\033[0;31m'
NC='\033[0m' # No Color
LYELLOW='\033[0;93m'
BLUE='\033[0;34m'
LGREEN='\033[0;92m'
ERRORS=""
NEWLINE=$'\n'
INFO='[INFO]:'
HEAD='[HEAD]:'
ERROR='[ERROR]:'

DEFAULT_EXPIRY=12h

setExtraHosts() {
  printInfo "Setting extra hosts..."

  local start=0
  extra_hosts=""
  while IFS= read -r line; do
    if [ "$line" ==  "# Hyperledger Fabric Host Configuration" ]; then
      start=1
      continue
    fi

    if [ "$line" ==  "# Append to /etc/hosts" ] && [ $start -eq 1 ]; then
      start=2
      continue
    fi

    if [ "$line" == "# end" ]; then
      # echo "$extra_hosts"
      printSuccess "Extra hosts set successfully"
      return
    fi 

    if [ "$start" -eq 2 ]; then
      if [ "$(echo $line | head -c 1)" == "#" ]; then
        continue
      fi

      if [ ! -z "$line" ]; then
        arr=($line)
        host="${arr[1]}:${arr[0]}"
        extra_hosts+="        - ${host}"$'\n'
      fi
    fi

  done < /etc/hosts

}

# Create config.yaml file for NODE OUs
createNodeOUs() {
  # setParams $1
  NODE_OUS_PATH=$1

  echo "NodeOUs:
    Enable: true
    ClientOUIdentifier:
        Certificate: cacerts/cacert.pem
        OrganizationalUnitIdentifier: client
    PeerOUIdentifier:
        Certificate: cacerts/cacert.pem
        OrganizationalUnitIdentifier: peer
    AdminOUIdentifier:
        Certificate: cacerts/cacert.pem
        OrganizationalUnitIdentifier: admin
    OrdererOUIdentifier:
        Certificate: cacerts/cacert.pem
        OrganizationalUnitIdentifier: orderer" > "$NODE_OUS_PATH"/config.yaml
}


# Create docker compose for TLS CA
createDockerTLSCA() {

setParams $1

echo "
# Docker compose file for creating Fabric TLS CAs

version: '3'

networks:
  main:

services:

  tlsca_${org}:
    image: hyperledger/fabric-ca:${CA_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=tlsca-${org}
      - FABRIC_LOGGING_SPEC=INFO
      # - FABRIC_LOGGING_SPEC=DEBUG
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      # - FABRIC_CA_SERVER_CSR_HOSTS=[localhost tlsca_${org} ${org}.domain.com]
      - FABRIC_CA_SERVER_PORT=${tlsPort}
      - FABRIC_CA_SERVER_SIGNING_PROFILES_TLS_EXPIRY=${DEFAULT_EXPIRY}
      - FABRIC_CA_SERVER_TLS_CLIENTAUTH_CERTFILES=ca-cert.pem
      - FABRIC_CA_SERVER_CA_REENROLLIGNORECERTEXPIRY=true
      # - FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:7003
    ports:
      - ${tlsPort}:${tlsPort}
    extra_hosts:
      # - \"tlsca_${org}:${tlsHost}\"
      - \"tlsca_${org}:127.0.0.1\"
    command: sh -c 'fabric-ca-server start -b ${admin}:${adminpw} -d'
    volumes:
      - ${FABRIC_HOME}/organizations/fabric-ca/${org}/fabric-tlsca-server-${org}:/etc/hyperledger/fabric-ca-server
    container_name: tlsca_${org}
    networks:
      - main" > docker/docker-compose-tls-${org}.yaml
}

# Create docker compose for TLS CA
createDockerTLSCAOps() {

setParams $1

echo "
# Docker compose file for creating Fabric TLS CAs

version: '3'

networks:
  main:

services:

  tlscaops_${org}:
    image: hyperledger/fabric-ca:${CA_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=tlscaops-${org}
      - FABRIC_LOGGING_SPEC=INFO
      # - FABRIC_LOGGING_SPEC=DEBUG
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      # - FABRIC_CA_SERVER_CSR_HOSTS=[localhost tlsopsca_${org} ${org}.domain.com]
      - FABRIC_CA_SERVER_PORT=${tlsOpsPort}
      - FABRIC_CA_SERVER_CA_REENROLLIGNORECERTEXPIRY=true
      # - FABRIC_CA_SERVER_SIGNING_PROFILES_TLS_EXPIRY=${DEFAULT_EXPIRY}
      # - FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:7001
    ports:
      - ${tlsOpsPort}:${tlsOpsPort}
    extra_hosts:
      - \"tlscaops_${org}:127.0.0.1\"
    command: sh -c 'fabric-ca-server start -b ${admin}:${adminpw} -d'
    volumes:
      - ${FABRIC_HOME}/organizations/fabric-ca/${org}/fabric-tlscaops-server-${org}:/etc/hyperledger/fabric-ca-server
    container_name: tlscaops_${org}
    networks:
      - main" > docker/docker-compose-tlsops-${org}.yaml
}

# Create the Docker compose file for the CA Server
createDockerCA() {

  setParams $1

  echo "
# Docker compose file for creating Fabric CAs

version: '3'

networks:
  main:

services:

  ca_${org}:
    image: hyperledger/fabric-ca:${CA_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-${org}
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      # - FABRIC_CA_SERVER_CSR_HOSTS=[localhost ca_${org} ${org}.domain.com]
      - FABRIC_CA_SERVER_PORT=${caPort}
      - FABRIC_CA_SERVER_CA_REENROLLIGNORECERTEXPIRY=true
      # - FABRIC_CA_SERVER_SIGNING_DEFAULT_EXPIRY=${DEFAULT_EXPIRY}
      # - FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:7002
    ports:
      - ${caPort}:${caPort}
    extra_hosts:
      - \"ca_${org}:127.0.0.1\"
    command: sh -c 'fabric-ca-server start -b ${caadmin}:${caadminpw} -d --cafiles users-ca/fabric-ca-server-config.yaml' 
    volumes:
      - ${FABRIC_HOME}/organizations/fabric-ca/${org}/fabric-ca-server-${org}:/etc/hyperledger/fabric-ca-server
    container_name: ca_${org}
    networks:
      - main
" > docker/docker-compose-ca-${org}.yaml
}


# Create docker compose file for Orderer
createDockerOrderer() {

  org=$1
  ordererId=$2
  ordererPort=$3
  
  setExtraHosts

  echo "
# Docker compose file for creating Orderers

version: '3'

volumes:
  ${ordererId}.${org}.domain.com:

networks:
  main:

services:

  ${ordererId}.${org}.domain.com:
    container_name: ${ordererId}.${org}.domain.com
    image: hyperledger/fabric-orderer:${FABRIC_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      # - ORDERER_OPERATIONS_LISTENADDRESS=0.0.0.0:9443
      - ORDERER_OPERATIONS_TLS_ENABLED=true
      - ORDERER_OPERATIONS_TLS_CERTIFICATE=/var/hyperledger/orderer/tlsops/signcerts/cert.pem
      - ORDERER_OPERATIONS_TLS_PRIVATEKEY=/var/hyperledger/orderer/tlsops/keystore/key.pem
      - ORDERER_OPERATIONS_TLS_CLIENTROOTCAS=/var/hyperledger/orderer/tlsops/tlscacerts/ca.crt
      - ORDERER_METRICS_PROVIDER=prometheus
      # - FABRIC_LOGGING_SPEC=DEBUG
      # - ORDERER_GENERAL_TLS_TLSHANDSHAKETIMESHIFT=15h
      # - ORDERER_GENERAL_CLUSTER_TLSHANDSHAKETIMESHIFT=15h
      # - ORDERER_GENERAL_AUTHENTICATION_NOEXPIRATIONCHECKS=true
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: orderer
    volumes:
      - ${FABRIC_HOME}/config/${ordererId}-${org}.yaml:/etc/hyperledger/fabric/orderer.yaml
      - ${FABRIC_HOME}/system-genesis-block/genesis.block:/var/hyperledger/orderer/genesis.block
      - ${FABRIC_HOME}/organizations/ordererOrganizations/${org}.domain.com/orderers/${ordererId}.${org}.domain.com/msp:/var/hyperledger/orderer/msp
      - ${FABRIC_HOME}/organizations/ordererOrganizations/${org}.domain.com/orderers/${ordererId}.${org}.domain.com/tls:/var/hyperledger/orderer/tls
      - ${ordererId}.${org}.domain.com:/var/hyperledger/production/orderer
      - ${FABRIC_HOME}/organizations/ordererOrganizations/${org}.domain.com/orderers/${ordererId}.${org}.domain.com/tlsops:/var/hyperledger/orderer/tlsops
      - ${CHANNEL_ARTIFACTS}:/var/hyperledger/orderer/channel-artifacts
    ports:
      - ${ordererPort}:${ordererPort}
      # - 9443:9443
    extra_hosts:
${extra_hosts}
    networks:
      - main
" > docker/docker-compose-${ordererId}-${org}.yaml
}

# Create docker compose file for Peer
createDockerPeer() {

  org=$1
  peerId=$2
  peerPort=$3

  setExtraHosts

  echo "
# Docker compose file for creating Peers

version: '3'

volumes:
  ${peerId}.${org}.domain.com:

networks:
  main:

services:

  ${peerId}.${org}.domain.com:
    container_name: ${peerId}.${org}.domain.com
    image: hyperledger/fabric-peer:${FABRIC_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      - grpc=debug:info
      - FABRIC_LOGGING_SPEC=INFO
      # - FABRIC_LOGGING_SPEC=error
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      # - CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=${COMPOSE_PROJECT_NAME}_main
      # COUCHDB CONFIG 
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=${peerId}couchDB${org}:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw  
      # On deployment
      # OPERATIONS CONFIG
      # - CORE_PEER_LISTENADDRESS=${peerId}.${org}.domain.com:7070
      # - CORE_PEER_ADDRESS=${peerId}.${org}.domain.com:7070
      # - CORE_PEER_CHAINCODELISTENADDRESS=${peerId}.${org}.domain.com:7071
      # - CORE_PEER_CHAINCODEADDRESS=${peerId}.${org}.domain.com:7070
      # - CORE_PEER_EXTERNALENDPOINT=${peerId}.${org}.domain.com:7070
      - CORE_OPERATIONS_TLS_ENABLED=true
      # - CORE_OPERATIONS_LISTENADDRESS=0.0.0.0:9443
      - CORE_OPERATIONS_TLS_CERT_FILE=/etc/hyperledger/fabric/tlsops/signcerts/cert.pem
      - CORE_OPERATIONS_TLS_KEY_FILE=/etc/hyperledger/fabric/tlsops/keystore/key.pem
      - CORE_OPERATIONS_TLS_CLIENTROOTCAS_FILES=/etc/hyperledger/fabric/tlsops/tlscacerts/ca.crt
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    volumes:
      - ${FABRIC_HOME}/config/${peerId}-${org}.yaml:/etc/hyperledger/fabric/core.yaml
      - /var/run/:/host/var/run/
      - ${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/msp:/etc/hyperledger/fabric/msp
      - ${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tls:/etc/hyperledger/fabric/tls
      - ${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tlsops:/etc/hyperledger/fabric/tlsops
      - ${peerId}.${org}.domain.com:/var/hyperledger/production
    ports:
      - "${peerPort}:${peerPort}"
      # - 9443:9443
    extra_hosts:
${extra_hosts}
    networks:
      - main

  ${peerId}cli.${org}:
    container_name: ${peerId}cli.${org}
    image: hyperledger/fabric-tools:${FABRIC_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    tty: true
    stdin_open: true
    environment:
      - GOPATH=/opt/gopath
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - FABRIC_LOGGING_SPEC=INFO
      # - FABRIC_LOGGING_SPEC=DEBUG
      - CORE_PEER_ID=${peerId}cli.${org}  
      # - CORE_PEER_ADDRESS=${peerId}.${org}.domain.com:${peerPort}
      - CORE_PEER_TLS_ENABLED=true
      - envPath=/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/envCli.sh
      # - CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
      # - CORE_PEER_TLS_CLIENTKEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tls/keystore/key.pem
      # - CORE_PEER_TLS_CLIENTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tls/signcerts/cert.pem
      - CORE_PEER_TLS_CERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tls/signcerts/cert.pem
      - CORE_PEER_TLS_KEY_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tls/keystore/key.pem
      - CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tls/tlscacerts/ca.crt
      - CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/msp
      # COUCHDB CONFIG 
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=${peerId}couchDB${org}:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw
      - CORE_OPERATIONS_LISTENADDRESS=0.0.0.0:9443
    working_dir: /opt/gopath/github.com/hyperledger/fabric/peer
    command: /bin/bash
    volumes:
      - ${FABRIC_HOME}/config/${peerId}-${org}.yaml:/etc/hyperledger/fabric/core.yaml
      - /var/run/:/host/var/run/
      - ${FABRIC_HOME}/chaincode/:/opt/gopath/src/github.com/chaincode
      - ${FABRIC_HOME}/organizations:/opt/gopath/src/github.com/hyperledger/fabric/peer/organizations
      - ${FABRIC_HOME}/scripts:/opt/gopath/src/github.com/hyperledger/fabric/peer/scripts/
      - ${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/msp:/etc/hyperledger/fabric/msp
      - ${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tls:/etc/hyperledger/fabric/tls
      # - ${FABRIC_HOME}/channel-artifacts:/opt/gopath/src/github.com/hyperledger/fabric/peer/channel-artifacts/
      - ${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tlsops:/etc/hyperledger/fabric/tlsops      
      - ${peerId}.${org}.domain.com:/var/hyperledger/production
    depends_on:
      - ${peerId}.${org}.domain.com
    extra_hosts:
${extra_hosts}
    networks:
      - main
" > docker/docker-compose-${peerId}-${org}.yaml

}

createDockerCouchDB() {
  org=$1
  peerId=$2
  # peerPort=$3
  dbPort=$3
  echo "
  
# Couch DB compose file for peers
version: '3'

networks:
  main:

services:
  ${peerId}couchDB${org}:
    container_name: ${peerId}couchDB${org}
    image: couchdb:3.1
    deploy:
      restart_policy:
        condition: on-failure
    environment: 
      - COUCHDB_USER=admin
      - COUCHDB_PASSWORD=adminpw
    ports:
      - ${dbPort}:5984
    networks:
      - main
" > docker/docker-couchDB-${peerId}-${org}.yaml
}

createMetrics() {

  setExtraHosts

  echo "
version: '3'

networks:
  main:

services:
  prometheus: 
    container_name: prometheus
    image: prom/prometheus 
    dns_search: .
    ports:
      - 9090:9090
    command:
      - --config.file=/etc/prometheus/prometheus.yaml       
    volumes: 
        - ${FABRIC_HOME}/config/prometheus.yaml:/etc/prometheus/prometheus.yaml
        - ${FABRIC_HOME}/organizations/peerOrganizations/lynkeus.domain.com/users/prometheus/tlsops:/etc/prometheus/lynkeus.domain.com/tlsops
        - ${FABRIC_HOME}/organizations/peerOrganizations/tex.domain.com/users/prometheus/tlsops:/etc/prometheus/tex.domain.com/tlsops
    extra_hosts:
${extra_hosts}   
    networks: 
        - main

  grafana:
    container_name: grafana
    image: grafana/grafana
    ports:
      - 4000:3000
    networks:
      - main
    depends_on:
      - prometheus" > "$FABRIC_HOME"/docker/prometheus.yaml
}

createDockerLogging() {

  echo "
version: '3'
services:
  dozzle:
    container_name: dozzle
    image: amir20/dozzle:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - 9999:8888 " > ${DOCKER_HOME}/dockerlogs.yaml

  echo "
version: '3'

services:
  portainer:
    image: portainer/portainer
    command: -H unix:///var/run/docker.sock
    restart: always
    ports:
      - 9000:9000
      - 8000:8000
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - portainer_data:/data

volumes:
  portainer_data: " > ${DOCKER_HOME}/portainer.yaml

  echo "
version: '3.7'

networks:
  main:
services:

  fluentd:
    image: wshihadeh/fluentd:1.0.0
    hostname: fluentd
    volumes:
     - fluentd-buffer:/fluentd/log
     - /var/lib/docker/containers:/var/lib/docker/containers
     - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - FLUENTD_CONF=fluentd.conf
      - ELASTICSEARCH_HOST=elasticsearch
      - ELASTICSEARCH_PORT=9200
      - ELASTICSEARCH_SCHEME=http
      - ENVIRONMENT=development.local
    deploy:
      mode: global
    logging:
      driver: json-file
      options:
        "max-size": "10m"
        "max-file": "5"
    networks:
      - main

  elasticsearch:
    image: elastic/elasticsearch:7.5.1
    environment:
      - discovery.type=single-node
      - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
    ulimits:
      nproc: 3000
      nofile: 65536
      memlock: -1
    logging:
      driver: json-file
      options:
        \"max-size\": \"10m\"
        \"max-file\": \"5\"
    deploy:
      update_config:
        delay: 10s
        order: start-first
        parallelism: 1
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
        window: 120s
      rollback_config:
        parallelism: 0
        order: stop-first
    networks:
      - main

  kibana:
    image: elastic/kibana:7.5.1
    ports:
      - 5601:5601
    deploy:
      restart_policy:
        condition: any
        delay: 5s
        max_attempts: 3
        window: 120s
      update_config:
        delay: 10s
        order: start-first
        parallelism: 1
      rollback_config:
        parallelism: 0
        order: stop-first
    environment:
        ELASTICSEARCH_URL: http://elasticsearch:9200
    networks:
      - main

volumes:
  fluentd-buffer:" > ${DOCKER_HOME}/log.yaml
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    printError "$2"
    ERRORS="${ERRORS} ${NEWLINE} $2"
    >&2 echo $2
    exit $1
  fi
}

printInfo() {
  echo
  date="$(date)"
  log="${date} ${INFO} $1" 
  echo -e "${LGREEN}${log}${NC}"
  if [ -z "${NO_SAVE_LOG}" ]; then
    echo "$log" >> ${LOG_PATH}/info.log
  fi
  echo
}

printSuccess() {
  echo
  date="$(date)"
  log="${date} ${INFO} $1" 
  echo -e "${BLUE}${log}${NC}"
  if [ -z "${NO_SAVE_LOG}" ]; then
    echo "$log" >> ${LOG_PATH}/info.log
  fi
  echo
}

printHead() {
  echo
  date="$(date)"
  log="${date} ${INFO} $1" 
  echo -e "${LGREEN}${log}${NC}"
  if [ -z "${NO_SAVE_LOG}" ]; then
    echo "$log" >> ${LOG_PATH}/info.log
  fi
  echo
}

printWarn() {
  echo
  date="$(date)"
  log="${date} ${HEAD} $1"
  echo -e "${LYELLOW}${log}${NC}"
  if [ -z "${NO_SAVE_LOG}" ]; then
    echo "$log" >> ${LOG_PATH}/info.log
  fi
  echo
}

printError() {
  echo
  date="$(date)"
  log="${date} ${ERROR} $1"
  echo -e "${RED}${date} ${ERROR} ${NC}: $1"
  if [ -z "${NO_SAVE_LOG}" ]; then
    echo "$log" >> ${LOG_PATH}/info.log
  fi
  echo "$log" >> ${LOG_PATH}/error.log
  echo
}