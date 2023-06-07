#!/bin/bash

export STAGE=dev

export FABRIC_HOME=${PWD}

# Profile used from configtx.yaml
export CHANNEL_PROFILE=AthLynkChannel

# Consortium name as written in configtx.yaml
export CONSORTIUM_NAME=BasicConsortium

# Set ORDERER global variables 
# export ORDERER_IP="$(getent hosts orderer0.ordererorg.domain.com |  tr -s ' ' | cut -d " " -f 1)"

if [ ${STAGE} == 'dev' ]; then
  export ORDERER=localhost:9051
else
  export ORDERER=orderer0.texorderer.domain.com:9051
fi

export ORDERER_HOSTNAME=orderer0.texorderer.domain.com
export ORDERER_CAFILE=${FABRIC_HOME}/organizations/ordererOrganizations/texorderer.domain.com/mspConfig/tlscacerts/ca.crt

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

setPorts() {
  org=$1
  declare -Ag PORT_MAP
  if [ "$org" == "tex" ]; then
    PORT_MAP[peer0]=7070
    PORT_MAP[peer1]=7080
  elif [ "$org" == "lynkeus" ]; then
    PORT_MAP[peer0]=8080
    PORT_MAP[peer1]=8090
  elif [ "$org" == "texorderer" ]; then
    PORT_MAP[orderer0]=9051
    PORT_MAP[orderer1]=9061
  elif [ "$org" == "lynkeusorderer" ]; then
    PORT_MAP[orderer0]=9071
  elif [ "$org" == "org3" ]; then
    PORT_MAP[peer0]=10070
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
    printWarn "Missing configuration for ${NODE_ID}-${org}."
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

# Set endorsing peers
setPeers() {

  if [ ${STAGE} == 'dev' ]; then
    peer0tex="--peerAddresses localhost:7070"
    peer1tex="--peerAddresses localhost:7080"

    peer0lyn="--peerAddresses localhost:8080"
    peer1lyn="--peerAddresses localhost:8090"
  else
    peer0tex="--peerAddresses peer0.tex.domain.com:7070"
    peer1tex="--peerAddresses peer1.tex.domain.com:7070"

    peer0lyn="--peerAddresses peer0.lynkeus.domain.com:7070"
    peer1lyn="--peerAddresses peer1.lynkeus.domain.com:7070"
  fi

  export TLS_ROOTCERT_TEX=${FABRIC_HOME}/organizations/peerOrganizations/tex.domain.com/mspConfig/tlscacerts/ca.crt
  export TLS_ROOTCERT_LYN=${FABRIC_HOME}/organizations/peerOrganizations/lynkeus.domain.com/mspConfig/tlscacerts/ca.crt

  tlsTex="--tlsRootCertFiles ${TLS_ROOTCERT_TEX}"
  tlsLyn="--tlsRootCertFiles ${TLS_ROOTCERT_LYN}"

  PEERS="$peer0tex $tlsTex $peer1tex $tlsTex $peer0lyn $tlsLyn $peer1lyn $tlsLyn"
}

# User Input
setParams() {
  org=$1

  typeOfOrg=peer
  if [ "$org" == "tex" ]; then
    caPort=7055
    tlsPort=7054
    peerPort=7070
    endorsingPeerPort=7080
    tlsOpsPort=7020
  elif [ "$org" == "lynkeus" ]; then
    caPort=8055
    tlsPort=8054
    peerPort=8080  
    endorsingPeerPort=8090
    tlsOpsPort=8020
  elif [ "$org" == "texorderer" ]; then
    typeOfOrg=orderer
    caPort=9055
    tlsPort=9054
    tlsOpsPort=9020  
  elif [ "$org" == "lynkeusorderer" ]; then
    typeOfOrg=orderer
    caPort=11055
    tlsPort=11054
    tlsOpsPort=11020
  elif [ "$org" == "org3" ]; then
    tlsOpsPort=10020
    caPort=10055
    tlsPort=10054
    peerPort=10070
  fi

  export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_PATH/${org}/fabric-ca-client-${org}
  export TLS_ROOTCERT_PATH=$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem
  export TLSOPS_ROOTCERT_PATH=$FABRIC_CA_CLIENT_HOME/tlsops-root-cert/tls-ca-cert.pem
  
  # CA 
  caHost=localhost
  caendpoint=$caHost:$caPort
  caName=ca-${org}
  caadmin=rcaadmin
  caadminpw=rcaadminpw
  userscaadmin=userscaadmin
  userscaadminpw=userscaadminpw

  # TLS 
  tlsadmin=tlsadmin
  tlsadminpw=tlsadminpw
  tlsHost=localhost
  tlsendpoint=${tlsHost}:${tlsPort}
  tlscaName=tlsca-${org}

  # TLS Ops
  tlsopsendpoint=${tlsHost}:${tlsOpsPort}
  tlsopscaName=tlsopsca-${org}

  # Admin User
  user=admin0
  userpw=admin0pw

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
  prometheuspw=secret123
}


