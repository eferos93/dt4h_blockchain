#!/bin/bash

export STAGE=prod

# Profile used from configtx.yaml
export CHANNEL_PROFILE=MarketplaceChannel
export CONSORTIUM_NAME=BasicConsortium

# Set ORDERER global variables 
# export ORDERER_IP="$(getent hosts orderer0.lynkeusorderer.domain.com |  tr -s ' ' | cut -d " " -f 1)"
export ORDERER_HOSTNAME=orderer0.lynkeusorderer.domain.com
export ORDERER_CAFILE=${FABRIC_HOME}/organizations/ordererOrganizations/lynkeusorderer.domain.com/mspConfig/tlscacerts/ca.crt

if [ ${STAGE} == 'dev' ]; then
  export ORDERER=localhost:9051
else
  export ORDERER=orderer0.lynkeusorderer.domain.com:9051
fi

################## THIS SECTION SHOULD BE CONFIGURED BY NETWORK ADMINISTRATOR #########################
################## MANDATORY PARAMETERS TO CONFIGURE ##########################
################## TLSHOST ##########################
################## CAHOST ##########################
################## TLSADMINPW ##########################
################## CAADMINPW ##########################
################## PEERPW ##########################
################## ORDERERPW ##########################
################## ADMINPW ##########################


# User Input 
[[ -z $ORGS ]] && export ORGS="tex lynkeus texorderer lynkeusorderer"
[[ -z $PEER_ORGS ]] && export PEER_ORGS="tex lynkeus"
[[ -z $ORDERER_ORGS ]] && export ORDERER_ORGS="texorderer lynkeusorderer"
export PEER_IDS="peer0 peer1"
export ORDERER_IDS="orderer0 orderer1"
export COUCHDB_PORTS=("5100" "5200" "6100" "6200")

# For CCP Generation
export CCP_PEER_PORT=7070
export CCP_ORDERER_PORT=9051
export CCP_CA_PORT=7055

setPorts() {
  org=$1

  PEER_PORT=7070
  if [ "$org" == "texorderer" ] || [ "$org" == "lynkeusorderer" ]; then
      PEER_PORT=9051
      CLUSTER_PORT=9052
  fi
}

# Set peer parameters for the peer cli 
setPeer() {
  org=$1 
  id=$2

  if [ -z "$id" ]; then
    id=peer0
  fi

  setPorts "$org"
  nodeID="$id"

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
  
  export CORE_PEER_ADDRESS=${nodeID}.${org}.domain.com:$PEER_PORT

  # MSP (Need Admin to join channel)
  export CORE_PEER_MSPCONFIGPATH=${PEER_HOME}/msp

}

# Set endorsing peers
setPeers() {

  peer0tex="--peerAddresses peer0.tex.domain.com:${CCP_PEER_PORT}"
  peer1tex="--peerAddresses peer1.tex.domain.com:${CCP_PEER_PORT}"

  peer0lyn="--peerAddresses peer0.lynkeus.domain.com:${CCP_PEER_PORT}"
  peer1lyn="--peerAddresses peer1.lynkeus.domain.com:${CCP_PEER_PORT}"

  export TLS_ROOTCERT_TEX=${FABRIC_HOME}/organizations/peerOrganizations/tex.domain.com/mspConfig/tlscacerts/ca.crt
  export TLS_ROOTCERT_LYN=${FABRIC_HOME}/organizations/peerOrganizations/lynkeus.domain.com/mspConfig/tlscacerts/ca.crt

  tlsTex="--tlsRootCertFiles ${TLS_ROOTCERT_TEX}"
  tlsLyn="--tlsRootCertFiles ${TLS_ROOTCERT_LYN}"

  PEERS="$peer0tex $tlsTex $peer1tex $tlsTex $peer0lyn $tlsLyn $peer1lyn $tlsLyn"
}

# User Input
setParams() {
  org=$1

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
  if [ "$org" == "lynkeusorderer" ] || [ "$org" == "texorderer" ]; then
    typeOfOrg=orderer
  fi
  
  export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_PATH/${org}/fabric-ca-client-${org}
  export TLS_ROOTCERT_PATH=$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem
  export TLSOPS_ROOTCERT_PATH=$FABRIC_CA_CLIENT_HOME/tlsops-root-cert/tls-ca-cert.pem
  
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
"167.172.190.194"
)

export HOSTS="# Hyperledger Fabric Host Configuration
# Append to /etc/hosts

# CAs
20.224.189.91 ca_lynkeus
20.224.189.91 tlsca_lynkeus

20.101.138.179 ca_tex
20.101.138.179 tlsca_tex

20.101.137.150 ca_lynkeusorderer
20.101.137.150 tlsca_lynkeusorderer

20.101.75.205 ca_texorderer
20.101.75.205 tlsca_texorderer

# endCAs

# Peers
20.123.159.122 peer0.lynkeus.domain.com
40.115.61.72 peer1.lynkeus.domain.com

20.4.76.222 peer0.tex.domain.com
20.101.106.73 peer1.tex.domain.com

# endPeers

# Orderers
20.23.253.97 orderer0.lynkeusorderer.domain.com
20.224.127.217 orderer0.texorderer.domain.com
13.80.52.99 orderer1.texorderer.domain.com

# endOrderers

# end
"