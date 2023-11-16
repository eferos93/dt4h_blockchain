#!/bin/bash

export STAGE=prod

# Base deployed machine directory
export REMOTE_BASE_DIRECTORY=~/workspace/deploy
export EXPORT_DEPLOYMENT_DIRECTORY=~/Desktop/deploy
export VM_USER=athena

# Profile used from configtx.yaml
export CHANNEL_PROFILE=MarketplaceChannel

# Consortium name as written in configtx.yaml
export CONSORTIUM_NAME=BasicConsortium

# Set ORDERER global variables 

# -- USER INPUT - Set Organization Names
export ORG_1=agora
export ORG_2=athena

# Auto set orderer of Org 1
export ORDERER_HOSTNAME=orderer0.${ORG_1}orderer.domain.com
export ORDERER_CAFILE=${FABRIC_HOME}/organizations/ordererOrganizations/${ORG_1}orderer.domain.com/mspConfig/tlscacerts/ca.crt
export ORDERER=orderer0.athenaorderer.domain.com:9051

# -- USER INPUT - Set Organizations
[[ -z $ORGS ]] && export ORGS="${ORG_1} ${ORG_2} ${ORG_1}orderer ${ORG_2}orderer"
[[ -z $PEER_ORGS ]] && export PEER_ORGS="${ORG_1} ${ORG_2}"
[[ -z $ORDERER_ORGS ]] && export ORDERER_ORGS="${ORG_1}orderer ${ORG_2}orderer"

export PEER_IDS="peer0 peer1"
export ORDERER_IDS="orderer0 orderer1"

# -- USER INPUT - Set CouchDB Ports
export COUCHDB_PORTS=("5100" "5200" "6100" "6200")

# For CCP Generation
export CCP_PEER_PORT=7070
export CCP_ORDERER_PORT=9051
export CCP_CA_PORT=7055

setPorts() {
  org=$1
  declare -Ag PORT_MAP
  if [ "$org" == "agora" ]; then
    PORT_MAP[peer0]=7070
    PORT_MAP[peer1]=7070
  elif [ "$org" == "athena" ]; then
    PORT_MAP[peer0]=7070
    PORT_MAP[peer1]=7070
  elif [ "$org" == "agoraorderer" ]; then
    PORT_MAP[orderer0]=9051
    PORT_MAP[orderer1]=9051
  elif [ "$org" == "athenaorderer" ]; then
    PORT_MAP[orderer0]=9051
  elif [ "$org" == "org3" ]; then
    PORT_MAP[peer0]=9051
  fi
}

# User Input
setParams() {
  org=$1
  
  export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_PATH/${org}/fabric-ca-client-${org}
  export TLS_ROOTCERT_PATH=$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem
  export TLSOPS_ROOTCERT_PATH=$FABRIC_CA_CLIENT_HOME/tlsops-root-cert/tls-ca-cert.pem
  
  # export myIP=$(dig +short myip.opendns.com @resolver1.opendns.com)
  tlsHost="$(getent hosts tlsca_${org} |  tr -s ' ' | cut -d " " -f 1)"
  caHost="$(getent hosts ca_${org} |  tr -s ' ' | cut -d " " -f 1)"

  ##### CA  PORTS #####
  tlsPort=7054
  caPort=7055
  tlsOpsPort=7040

  ##### PEER PORTS #####
  peerPort=7070

  ##### ORG TYPE #####
  typeOfOrg=peer
  if [ "$org" == "athenaorderer" ] || [ "$org" == "agoraorderer" ]; then
    typeOfOrg=orderer
  fi

  
  # CA 
  caendpoint=$caHost:$caPort
  caName=ca-${org}
  caadmin=rcaadmin
  caadminpw=rcaadminpw
  userscaadmin=userscaadmin
  userscaadminpw=userscaadminpw

  # TLS 
  tlsadmin=tlsadmin
  tlsadminpw=tlsadminpw
  tlsendpoint=${tlsHost}:${tlsPort}
  tlscaName=tlsca-${org}

  # TLS Ops
  tlsopsendpoint=${tlsHost}:${tlsOpsPort}
  tlsopscaName=tlsopsca-${org}

  # Admin User
  userpw=admin0pw
  user=admin0

  # Block Client 
  blockclient=blockclient
  blockclientpw=blockclientpw

  # Peer
  # peer=peer
  peerpw=peerpw
  
  # Orderer
  # orderer=orderer
  ordererpw=ordererpw

  # Org Admin ID-Secret
  admin=admin
  adminpw=adminpw
  
  # Prometheus
  prometheus=prometheus
  prometheuspw=prometheuspw
}

export VM_IPS=(
"xx.xxx.xx.xx", 
"xx.xxx.xx.xx" 
)

export HOSTS="# Hyperledger Fabric Host Configuration
# Append to /etc/hosts

# CAs
xx.xx.xx.xx ca_${ORG_1}
xx.xx.xx.xx tlsca_${ORG_1}

xx.xx.xx.xx ca_${ORG_2}
xx.xx.xx.xx tlsca_${ORG_2}

xx.xx.xx.xx ca_${ORG_1}orderer
xx.xx.xx.xx tlsca_${ORG_1}orderer

xx.xx.xx.xx ca_${ORG_2}orderer
xx.xx.xx.xx tlsca_${ORG_2}orderer

# endCAs

# Peers
xx.xx.xx.xx peer0.${ORG_1}.domain.com
xx.xx.xx.xx peer1.${ORG_1}.domain.com

xx.xx.xx.xx peer0.${ORG_2}.domain.com
xx.xx.xx.xx peer1.${ORG_2}.domain.com

# endPeers

# Orderers
xx.xx.xx.xx orderer0.${ORG_1}orderer.domain.com
xx.xx.xx.xx orderer0.${ORG_2}orderer.domain.com
xx.xx.xx.xx orderer1.${ORG_1}orderer.domain.com

# endOrderers

# end
"