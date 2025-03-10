#!/bin/bash

export STAGE=dev

# Profile used from configtx.yaml
export CHANNEL_PROFILE=dt4h

# Consortium name as written in configtx.yaml
export CONSORTIUM_NAME=BasicConsortium

# Set ORDERER global variables 

# -- USER INPUT - Sest Organization Names
export ORG_1=athena
export ORG_2=ub
export ORG_3=bsc

# Auto set orderer of Org 1
export ORDERER_HOSTNAME=orderer0.${ORG_1}orderer.domain.com
export ORDERER_CAFILE=${FABRIC_HOME}/organizations/ordererOrganizations/${ORG_1}orderer.domain.com/mspConfig/tlscacerts/ca.crt
export ORDERER=localhost:9051

[[ -z $ORGS ]] && export ORGS="${ORG_1} ${ORG_2} ${ORG_3}"
[[ -z $PEER_ORGS ]] && export PEER_ORGS="${ORG_2} ${ORG_3}"
[[ -z $ORDERER_ORGS ]] && export ORDERER_ORGS="${ORG_1}"

export PEER_IDS="peer0 peer1"
export ORDERER_IDS="orderer0 orderer1"

# -- USER INPUT - Set CouchDB Ports
export COUCHDB_PORTS=("5100" "5200" "6100" "6200")

# -- ORG ADMINS USERNAMES AND PASSWORDS --
export ADMIN_USER=admin0
export ADMIN_USER_PW=admin0pw
export ORG_REGISTRAR=registrar0
export ORG_REGISTRAR_PW=registrarpw

# softhsm
export SOFTHSM2_CONF="${SOFTHSM2_CONF:-${HOME}/softhsm2.conf}"

LocateHsmLib() {
  local POSSIBLE_LIB_LOC=( \
    '/usr/lib/softhsm/libsofthsm2.so' \
    '/usr/lib/x86_64-linux-gnu/softhsm/libsofthsm2.so' \
    '/usr/local/lib/softhsm/libsofthsm2.so' \
    '/usr/lib/libacsp-pkcs11.so' \
    '/opt/homebrew/lib/softhsm/libsofthsm2.so' \
  )
  for TEST_LIB in "${POSSIBLE_LIB_LOC[@]}"; do
    if [ -f "${TEST_LIB}" ]; then
      echo "${TEST_LIB}"
      return
    fi
  done
}

HSM2_LIB="${PKCS11_LIB:-$(LocateHsmLib)}"
[ -z "${HSM2_LIB}" ] && echo No SoftHSM PKCS11 Library found, ensure you have installed softhsm2 && exit 1

# create a softhsm2.conf file if one doesn't exist
if [ ! -f "${SOFTHSM2_CONF}" ]; then
  TMPDIR="${TMPDIR:-/tmp}"
  mkdir -p "${TMPDIR}/softhsm"
  echo "directories.tokendir = ${TMPDIR}/softhsm" > "${SOFTHSM2_CONF}"
fi

# create a softhsm2.conf file if one doesn't exist
if [ ! -f "${SOFTHSM2_CONF}" ]; then
  TMPDIR="${TMPDIR:-/tmp}"
  mkdir -p "${TMPDIR}/softhsm"
  echo "directories.tokendir = ${TMPDIR}/softhsm" > "${SOFTHSM2_CONF}"
fi

# Helper functions for PORT_MAP associative array working for bash versions prior to 4.0
# Declare indexed arrays for keys and values
declare -a keys
declare -a values

function PORT_MAP_set_pair {
    local key="$1"
    local value="$2"
    for ((i = 0; i < ${#keys[@]}; i++)); do
        if [ "${keys[$i]}" = "$key" ]; then
            values[$i]=$value
            return
        fi
    done
    keys+=("$1")
    values+=("$2")
}

function PORT_MAP_get_value_by_key {
    local key="$1"
    for ((i = 0; i < ${#keys[@]}; i++)); do
        if [ "${keys[$i]}" = "$key" ]; then
            echo "${values[$i]}"
            return
        fi
    done
    echo "Key not found: $key"
}

# -- USER INPUT - Set Peer Ports
# -- Improvement proposal: Make it work dynamically with the number of peers
setPorts() {
  org=$1

  if [ "$org" == "${ORG_1}" ]; then
    PORT_MAP_set_pair "orderer0" 7070
    PORT_MAP_set_pair "orderer1" 7080
  elif [ "$org" == "${ORG_2}" ]; then
    PORT_MAP_set_pair "peer0" 8080
    PORT_MAP_set_pair "peer1" 8090
  elif [ "$org" == "${ORG_3}" ]; then
    PORT_MAP_set_pair "peer0" 9051
    PORT_MAP_set_pair "peer1" 9061
  fi
}


# -- USER INPUT - Set Parameters
setParams() {
  org=$1

  export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_PATH/${org}/fabric-ca-client-${org}
  export TLS_ROOTCERT_PATH=$FABRIC_CA_CLIENT_HOME/tls-root-cert/tls-ca-cert.pem
  export TLSOPS_ROOTCERT_PATH=$FABRIC_CA_CLIENT_HOME/tlsops-root-cert/tls-ca-cert.pem

  if [ "$org" == "${ORG_1}" ]; then
    typeOfOrg=orderer
    caPort=7055
    tlsPort=7054
    peerPort=7070
    tlsOpsPort=7020
  elif [ "$org" == "${ORG_2}" ]; then
    typeOfOrg=peer
    caPort=8055
    tlsPort=8054
    peerPort=8080  
    tlsOpsPort=8020
  elif [ "$org" == "${ORG_3}" ]; then
    typeOfOrg=peer
    tlsOpsPort=10020
    caPort=10055
    tlsPort=10054
    peerPort=10070
  fi
  
  # CA 
  caHost=localhost
  caName=ca-${org}
  caendpoint=$caHost:$caPort

  export CA_PORT=$caPort
  export CA_HOST=$caHost
  export CA_ENDPOINT=$caendpoint
  export CA_NAME=$caName

  caadmin=rcaadmin
  caadminpw=rcaadminpw
  userscaadmin=userscaadmin
  userscaadminpw=userscaadminpw

  export CA_ADMIN=$caadmin
  export CA_ADMINPW=$caadminpw
  export USERSCA_ADMIN=$userscaadmin
  export USERSCA_ADMINPW=$userscaadminpw

  # TLS 
  tlsadmin=tlsadmin
  tlsadminpw=tlsadminpw
  tlsHost=localhost
  tlsendpoint=${tlsHost}:${tlsPort}
  tlscaName=tlsca-${org}

  export TLS_ADMIN=$tlsadmin
  export TLS_ADMINPW=$tlsadminpw
  export TLS_HOST=$tlsHost
  export TLS_ENDPOINT=$tlsendpoint
  export TLS_CANAME=$tlscaName

  # TLS Ops
  tlsopsendpoint=${tlsHost}:${tlsOpsPort}
  tlsopscaName=tlsopsca-${org}

  export TLSOPS_ENDPOINT=$tlsopsendpoint
  export TLSOPS_CANAME=$tlsopscaName
  export TLSOPS_PORT=$tlsOpsPort

  # Admin User
  export ORG_USERS_ADMIN=admin0
  export ORG_USERS_ADMIN_PW=admin0

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
