#!/bin/bash

# Standard project paths
export FABRIC_HOME=${PWD}
export FABRIC_CFG_PATH=${FABRIC_HOME}/config
export BINPATH=${FABRIC_HOME}/bin
export FABRIC_CA_CFG_PATH=${FABRIC_HOME}/config
export FABRIC_CA_PATH=${FABRIC_HOME}/organizations/fabric-ca
export PATH=$PATH:${BINPATH}
export DOCKER_HOME=${FABRIC_HOME}/docker
export LOG_PATH=${FABRIC_HOME}/logs
export CHANNEL_ARTIFACTS=${FABRIC_HOME}/channel-artifacts
export TX=${CHANNEL_ARTIFACTS}/update_in_envelope.pb

# Application Path
export APP_PATH=${FABRIC_HOME}/application-typescript/

# API Paths
export FABRIC_PEER_API=${FABRIC_HOME}/api/peerAPI
export FABRIC_CA_API=${FABRIC_HOME}/api/caAPI
export FABRIC_TOOLS_API=${FABRIC_HOME}/api/toolsAPI

# Docker Env
export COMPOSE_PROJECT_NAME=fabric
export COMPOSE_IGNORE_ORPHANS=True

# Fabric Version of binaries
export CA_TAG=1.5.1
export FABRIC_TAG=2.2.5

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

TLS_DEFAULT_EXPIRY=43830h
CA_DEFAULT_EXPIRY=17532h


# Set endorsing peers
setPeers() {

  if [ ${STAGE} == 'dev' ]; then
    peer0Org1="--peerAddresses localhost:7070"
    peer1Org1="--peerAddresses localhost:7080"

    peer0Org2="--peerAddresses localhost:8080"
    peer1Org2="--peerAddresses localhost:8090"
  else
    peer0Org1="--peerAddresses peer0.${ORG_1}.domain.com:${CCP_PEER_PORT}"
    peer1Org1="--peerAddresses peer1.${ORG_1}.domain.com:${CCP_PEER_PORT}"

    peer0Org2="--peerAddresses peer0.${ORG_2}.domain.com:${CCP_PEER_PORT}"
    peer1Org2="--peerAddresses peer1.${ORG_2}.domain.com:${CCP_PEER_PORT}"
  fi

  export TLS_ROOTCERT_ORG1=${FABRIC_HOME}/organizations/peerOrganizations/${ORG_1}.domain.com/mspConfig/tlscacerts/ca.crt
  export TLS_ROOTCERT_ORG2=${FABRIC_HOME}/organizations/peerOrganizations/${ORG_2}.domain.com/mspConfig/tlscacerts/ca.crt

  tlsOrg1="--tlsRootCertFiles ${TLS_ROOTCERT_ORG1}"
  tlsOrg2="--tlsRootCertFiles ${TLS_ROOTCERT_ORG2}"

  PEERS="$peer0Org1 $tlsOrg1 $peer1Org1 $tlsOrg1 $peer0Org2 $tlsOrg2 $peer1Org2 $tlsOrg2"
}

# Set peer parameters for the peer cli 
setPeer() {
  org=$1 
  nodeID=$2

  if [ -z "$nodeID" ]; then
    nodeID=peer0
  fi

  setPorts "$org"

  # Set hostname depending on deployed or localhost version
  [ ${STAGE} == 'dev' ] && hostname=localhost || hostname=${nodeID}.${org}.domain.com

  # Check config existence
  if [ ! -f ${FABRIC_CFG_PATH}/${nodeID}-${org}.yaml ]; then
    printWarn "Missing configuration for ${nodeID}-${org}."
    # exit 1
  fi

  # Set Env Vars to transact as a specific node
  if [[ "$TYPE" == 'orderer' ]]; then
    # Case Orderer
    export PEER_HOME=${FABRIC_HOME}/organizations/ordererOrganizations/${org}.domain.com/orderers/${nodeID}.${org}.domain.com
  else
    # Case Peer
    export PEER_HOME=${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${nodeID}.${org}.domain.com
    cp ${FABRIC_CFG_PATH}/${nodeID}-${org}.yaml ${FABRIC_CFG_PATH}/core.yaml
  fi

  export CORE_PEER_TLS_ROOTCERT_FILE=${PEER_HOME}/tls/tlscacerts/ca.crt
  export CORE_PEER_TLS_CERT=${PEER_HOME}/tls/signcerts/cert.pem
  export CORE_PEER_TLS_KEY=${PEER_HOME}/tls/keystore/key.pem
  
  export CORE_PEER_ADDRESS=${hostname}:${PORT_MAP[$nodeID]}

  # MSP (Need Admin to join channel)
  export CORE_PEER_MSPCONFIGPATH=${PEER_HOME}/msp

}

setExtraHosts() {
  printInfo "Setting extra hosts..."

  local case=0
  extra_hosts=""
  while IFS= read -r line; do
    if [ "$line" ==  "# Hyperledger Fabric Host Configuration" ]; then
      case=1
      continue
    fi

    if [ "$line" ==  "# Append to /etc/hosts" ] && [ $case -eq 1 ]; then
      case=2
      continue
    fi

    if [ "$line" == "# end" ]; then
      # echo "$extra_hosts"
      printSuccess "Extra hosts set successfully"
      return
    fi 

    if [ "$case" -eq 2 ]; then
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

ops_listenaddress="- FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:7003"
[ ${STAGE} == 'dev' ] && ops_listenaddress="# ${ops_listenaddress}"

echo "
# Docker compose file for creating Fabric TLS CAs

version: '3'

networks:
  ${STAGE}:

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
      - FABRIC_CA_SERVER_REGISTRY_IDENTITIES_0_NAME=${tlsadmin}
      - FABRIC_CA_SERVER_REGISTRY_IDENTITIES_0_PASS=${tlsadminpw}
      - FABRIC_CA_SERVER_CSR_HOSTS=tlsca_${org},${org}.domain.com,${tlsHost}
      - FABRIC_CA_SERVER_CSR_NAMES_0_O=${org}
      - FABRIC_CA_SERVER_CSR_NAMES_0_OU=${org}-tls
      - FABRIC_CA_SERVER_PORT=${tlsPort}
      - FABRIC_CA_SERVER_TLS_CLIENTAUTH_CERTFILES=ca-cert.pem
      - FABRIC_CA_SERVER_CA_REENROLLIGNORECERTEXPIRY=true
      - FABRIC_CA_SERVER_SIGNING_PROFILES_TLS_EXPIRY=${TLS_DEFAULT_EXPIRY}
      ${ops_listenaddress}
    ports:
      - ${tlsPort}:${tlsPort}
    extra_hosts:
      - \"tlsca_${org}:127.0.0.1\"
      # - \"tlsca_${org}:${tlsHost}\"
    command: sh -c 'fabric-ca-server start -b ${admin}:${adminpw} -d'
    volumes:
      - ${FABRIC_HOME}/organizations/fabric-ca/${org}/fabric-tlsca-server-${org}:/etc/hyperledger/fabric-ca-server
    container_name: tlsca_${org}
    networks:
      - ${STAGE}" > docker/docker-compose-tls-${org}.yaml
}

# Create docker compose for TLS CA
createDockerTLSCAOps() {

setParams $1

ops_listenaddress="- FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:7001"
[ ${STAGE} == 'dev' ] && ops_listenaddress="# ${ops_listenaddress}"

echo "
# Docker compose file for creating Fabric TLS CAs

version: '3'

networks:
  ${STAGE}:

services:

  tlscaops_${org}:
    image: hyperledger/fabric-ca:${CA_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=tlscaops-${org}
      - FABRIC_CA_SERVER_PORT=${tlsOpsPort}
      # - FABRIC_LOGGING_SPEC=DEBUG
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_CSR_NAMES_0_O=${org}
      - FABRIC_CA_SERVER_CSR_NAMES_0_OU=${org}-tlsops
      - FABRIC_CA_SERVER_CSR_HOSTS=tlsopsca_${org},${org}.domain.com,${tlsHost}
      - FABRIC_CA_SERVER_CA_REENROLLIGNORECERTEXPIRY=true
      - FABRIC_CA_SERVER_SIGNING_PROFILES_TLS_EXPIRY=${TLS_DEFAULT_EXPIRY}
      ${ops_listenaddress}
    ports:
      - ${tlsOpsPort}:${tlsOpsPort}
    extra_hosts:
      - \"tlscaops_${org}:127.0.0.1\"
    command: sh -c 'fabric-ca-server start -b ${admin}:${adminpw} -d'
    volumes:
      - ${FABRIC_HOME}/organizations/fabric-ca/${org}/fabric-tlscaops-server-${org}:/etc/hyperledger/fabric-ca-server
    container_name: tlscaops_${org}
    networks:
      - ${STAGE}" > docker/docker-compose-tlsops-${org}.yaml
}

# Create the Docker compose file for the CA Server
createDockerCA() {

  setParams $1

ops_listenaddress="- FABRIC_CA_SERVER_OPERATIONS_LISTENADDRESS=0.0.0.0:7002"
[ ${STAGE} == 'dev' ] && ops_listenaddress="# ${ops_listenaddress}"

  echo "
# Docker compose file for creating Fabric CAs

version: '3'

networks:
  ${STAGE}:

services:

  ca_${org}:
    image: hyperledger/fabric-ca:${CA_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      - FABRIC_LOGGING_SPEC=INFO
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca-${org}
      - FABRIC_CA_SERVER_PORT=${caPort}
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_REGISTRY_IDENTITIES_0_NAME=${caadmin}
      - FABRIC_CA_SERVER_REGISTRY_IDENTITIES_0_PASS=${caadminpw}
      - FABRIC_CA_SERVER_CSR_HOSTS=ca_${org},${org}.domain.com,${caHost}
      - FABRIC_CA_SERVER_CSR_NAMES_0_O=${org}
      - FABRIC_CA_SERVER_CA_REENROLLIGNORECERTEXPIRY=true
      - FABRIC_CA_SERVER_SIGNING_TLS_DEFAULT_EXPIRY=${CA_DEFAULT_EXPIRY}
      - FABRIC_CA_SERVER_AFFILIATIONS_${org}=MEMBERS,USERS
      ${ops_listenaddress}
    ports:
      - ${caPort}:${caPort}
    extra_hosts:
      - \"ca_${org}:127.0.0.1\"
    command: sh -c 'fabric-ca-server start -b ${caadmin}:${caadminpw} -d --cafiles users-ca/fabric-ca-server-config.yaml' 
    volumes:
      - ${FABRIC_HOME}/organizations/fabric-ca/${org}/fabric-ca-server-${org}:/etc/hyperledger/fabric-ca-server
    container_name: ca_${org}
    networks:
      - ${STAGE}
" > docker/docker-compose-ca-${org}.yaml
}


# Create docker compose file for Orderer
createDockerOrderer() {

  org=$1
  ordererId=$2
  ordererPort=$3

  let CLUSTER_PORT=$ordererPort+1
  ops_listenaddress="- ORDERER_OPERATIONS_LISTENADDRESS=0.0.0.0:9443"
  cl_lAddress="- ORDERER_GENERAL_CLUSTER_LISTENPORT=${CLUSTER_PORT}"
  ops_port="- 9443:9443"
  [ ${STAGE} == 'dev' ] && ops_listenaddress="# ${ops_listenaddress}"
  [ ${STAGE} == 'dev' ] && ops_port="# ${ops_port}"
  [ ${STAGE} == 'dev' ] && cl_lAddress="# ${cl_lAddress}"
  
  echo "
# Docker compose file for creating Orderers

version: '3'

volumes:
  ${ordererId}.${org}.domain.com:

networks:
  ${STAGE}:

services:

  ${ordererId}.${org}.domain.com:
    container_name: ${ordererId}.${org}.domain.com
    image: hyperledger/fabric-orderer:${FABRIC_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      #### GENERAL
      - FABRIC_LOGGING_SPEC=INFO
      # - FABRIC_LOGGING_SPEC=DEBUG
      #### CORE ORDERER
      - ORDERER_GENERAL_LISTENPORT=${ordererPort}
      #### FOR CERT ROTATION
      # - ORDERER_GENERAL_TLS_TLSHANDSHAKETIMESHIFT=15h
      # - ORDERER_GENERAL_CLUSTER_TLSHANDSHAKETIMESHIFT=15h
      # - ORDERER_GENERAL_AUTHENTICATION_NOEXPIRATIONCHECKS=true
      #### OPERATIONS
      - ORDERER_OPERATIONS_TLS_ENABLED=true
      - ORDERER_OPERATIONS_TLS_CERTIFICATE=/var/hyperledger/orderer/tlsops/signcerts/cert.pem
      - ORDERER_OPERATIONS_TLS_PRIVATEKEY=/var/hyperledger/orderer/tlsops/keystore/key.pem
      - ORDERER_OPERATIONS_TLS_CLIENTROOTCAS=/var/hyperledger/orderer/tlsops/tlscacerts/ca.crt
      - ORDERER_METRICS_PROVIDER=prometheus
      ${ops_listenaddress}
      ${cl_lAddress}
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
      - ${CLUSTER_PORT}:${CLUSTER_PORT}
      - ${ordererPort}:${ordererPort}
      ${ops_port}
    networks:
      - ${STAGE}
" > docker/docker-compose-${ordererId}-${org}.yaml

if [ ${STAGE} != 'dev' ]; then 
  setExtraHosts
echo "    extra_hosts:
${extra_hosts}" >> docker/docker-compose-${ordererId}-${org}.yaml
fi

}

# Create docker compose file for Peer
createDockerPeer() {

  org=$1
  peerId=$2
  peerPort=$3
  chaincodePort=$(expr ${peerPort} + 1)

  ops_listenaddress="- CORE_OPERATIONS_LISTENADDRESS=0.0.0.0:9443"
  ops_port="- 9443:9443"
  [ ${STAGE} == 'dev' ] && ops_listenaddress="# ${ops_listenaddress}"
  [ ${STAGE} == 'dev' ] && ops_port="# ${ops_port}"

  echo "
# Docker compose file for creating Peers

version: '3'

volumes:
  ${peerId}.${org}.domain.com:

networks:
  ${STAGE}:

services:

  ${peerId}.${org}.domain.com:
    container_name: ${peerId}.${org}.domain.com
    image: hyperledger/fabric-peer:${FABRIC_TAG}
    dns_search: .
    deploy:
      restart_policy:
        condition: on-failure
    environment:
      #### GENERAL CONFIG
      - grpc=debug:info
      - FABRIC_LOGGING_SPEC=INFO
      # - FABRIC_LOGGING_SPEC=DEBUG
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=${COMPOSE_PROJECT_NAME}_${STAGE}
      #### COUCHDB CONFIG 
      - CORE_LEDGER_STATE_COUCHDBCONFIG_COUCHDBADDRESS=${peerId}couchDB${org}:5984
      - CORE_LEDGER_STATE_COUCHDBCONFIG_USERNAME=admin
      - CORE_LEDGER_STATE_COUCHDBCONFIG_PASSWORD=adminpw  
      #### PEER ADDRESSES CONFIG
      - CORE_PEER_ID=${peerId}.${org}.domain.com
      - CORE_PEER_LISTENADDRESS=0.0.0.0:${peerPort}
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:${chaincodePort}
      - CORE_PEER_ADDRESS=${peerId}.${org}.domain.com:${peerPort}
      - CORE_PEER_CHAINCODEADDRESS=${peerId}.${org}.domain.com:${chaincodePort}
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=${peerId}.${org}.domain.com:${peerPort}
      - CORE_PEER_GOSSIP_BOOTSTRAP=${peerId}.${org}.domain.com:${peerPort}
      #### OPERATIONS CONFIG
      - CORE_OPERATIONS_TLS_ENABLED=true
      ${ops_listenaddress}
      - CORE_OPERATIONS_TLS_CERT_FILE=/etc/hyperledger/fabric/tlsops/signcerts/cert.pem
      - CORE_OPERATIONS_TLS_KEY_FILE=/etc/hyperledger/fabric/tlsops/keystore/key.pem
      - CORE_OPERATIONS_TLS_CLIENTROOTCAS_FILES=/etc/hyperledger/fabric/tlsops/tlscacerts/ca.crt
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric/peer
    command: peer node start
    volumes:
      - ${FABRIC_HOME}/config/core.yaml:/etc/hyperledger/fabric/core.yaml
      - /var/run/:/host/var/run/
      - ${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/msp:/etc/hyperledger/fabric/msp
      - ${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tls:/etc/hyperledger/fabric/tls
      - ${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/peers/${peerId}.${org}.domain.com/tlsops:/etc/hyperledger/fabric/tlsops
      - ${peerId}.${org}.domain.com:/var/hyperledger/production
    ports:
      - "${peerPort}:${peerPort}"
      ${ops_port}
    networks:
      - ${STAGE}" > docker/docker-compose-${peerId}-${org}.yaml

if [ ${STAGE} != 'dev' ]; then 
  setExtraHosts
echo "    extra_hosts:
${extra_hosts}" >> docker/docker-compose-${peerId}-${org}.yaml
fi

echo  "
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
      - ${FABRIC_HOME}/config/core.yaml:/etc/hyperledger/fabric/core.yaml
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
    networks:
      - ${STAGE}" >> docker/docker-compose-${peerId}-${org}.yaml

if [ ${STAGE} != 'dev' ]; then 
  setExtraHosts
echo "    extra_hosts:
${extra_hosts}" >> docker/docker-compose-${peerId}-${org}.yaml
fi

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
  ${STAGE}:

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
      - ${STAGE}
" > docker/docker-couchDB-${peerId}-${org}.yaml
}

createMetrics() {

  echo "
version: '3'

networks:
  ${STAGE}:

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
    networks: 
        - ${STAGE}" > "$FABRIC_HOME"/docker/prometheus.yaml

if [ ${STAGE} != 'dev' ]; then 
  setExtraHosts
echo "    extra_hosts:
${extra_hosts}" >> "$FABRIC_HOME"/docker/prometheus.yaml
fi

echo "
  grafana:
    container_name: grafana
    image: grafana/grafana
    ports:
      - 4000:3000
    networks:
      - ${STAGE}
    depends_on:
      - prometheus" >> "$FABRIC_HOME"/docker/prometheus.yaml
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
  ${STAGE}:
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
      - ${STAGE}

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
      - ${STAGE}

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
      - ${STAGE}

volumes:
  fluentd-buffer:" > ${DOCKER_HOME}/log.yaml
}

verifyResult() {
  if [ $1 -ne 0 ]; then
    printError "$2"
    ERRORS="${ERRORS} ${NEWLINE} $2"
    # >&2 echo $2
  fi
  # return $1
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
  log="${date} ${WARN} $1"
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