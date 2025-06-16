#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script's functionality is used to generate a ccp.yaml from $HOSTS 


generateCCP() {

  printInfo "Generating CCP using hostnames and IPs from /etc/hosts..."
  if [[ "$STAGE" == 'dev' ]]; then
    printError "generateCCP - You are on localhost (STAGE=dev). HOSTS not set. "
    return
  fi

  extractIPs
  printSuccess "Saving ccp at ./ccp.yaml"
  echo "$ccp" > ccp.yaml
}

extractIPs() {

  all_cas="$(grep " ca" <<< "$HOSTS")"
  all_peers="$(grep " peer" <<< "$HOSTS")"
  all_orderers="$(grep " orderer" <<< "$HOSTS")"

  ORGS="$(echo $(awk -F ' ' '{print $2}' <<< $all_peers | cut -d "." -f 2) | xargs -n 1 | sort -u)"

  make_header "$(echo $ORGS | cut -d " " -f 2)"

  ccp+="peers:"
  while IFS=" " read -ra peer; do
        

    ORG_NAME="$(echo "${peer[1]}" | cut -d "." -f 2)"
    ccp+="  
  ${peer[1]}:
    url: grpcs://${peer[0]}:${CCP_PEER_PORT}
    tlsCACerts:
      path: ../organizations/peerOrganizations/${ORG_NAME}.dt4h.com/mspConfig/tlscacerts/ca.crt
    grpcOptions:
      hostnameOverride: ${peer[1]}
      grpc.keepalive_timeout_ms: 20000
      ssl-target-name-override: ${peer[1]}

"
  done < <(printf '%s\n' "$all_peers")
    
  ccp+="orderers:"
  while IFS=" " read -ra orderer; do

    ORG_NAME="$(echo "${orderer[1]}" | cut -d "." -f 2)"
    ccp+="  
  ${orderer[1]}:
    url: grpcs://${orderer[0]}:${CCP_ORDERER_PORT}
    grpcOptions:
      ssl-target-name-override: ${orderer[1]}
      hostnameOverride: ${orderer[1]}
      grpc.keepalive_timeout_ms: 20000
    tlsCACerts:
      path: ../organizations/ordererOrganizations/${ORG_NAME}.dt4h.com/mspConfig/tlscacerts/ca.crt

"

  done < <(printf '%s\n' "$all_orderers")

  ccp+="certificateAuthorities:"
  while IFS=" " read -ra ca; do

    if [[ "${ca[1]}" =~ "orderer" ]]; then
      continue
    fi

    ORG_NAME="$(echo "${ca[1]}" | cut -d "_" -f 2)"

    ccp+="  
  ${ca[1]}:
    url: https://${ca[0]}:${CCP_CA_PORT}
    caName: ${ca[1]}
    tlsCACerts:
      path: ../organizations/peerOrganizations/${ORG_NAME}.dt4h.com/mspConfig/tlscacerts/ca.crt
    httpOptions:
      verify: true
"

  done < <(printf '%s\n' "$all_cas")

}

make_header() {

  ccp="---
name: fabric_main
version: \"1.1\"
client:
  organization: $1
  connection:
    timeout:
      peer:
        endorser: '300'
"

  ccp+="
channels:
  ${CHANNEL_NAME}:
    orderers:
"
  
  while IFS=" " read -ra orderer; do
    ccp+="      - ${orderer[1]}
"
  done < <(printf '%s\n' "$all_orderers")
  
  ccp+="    peers:
"

  while IFS=" " read -ra peer; do
    # orgs=
    ccp+="      - ${peer[1]}
"
  done < <(printf '%s\n' "$all_peers")


  ccp+="
organizations:
"

  for org in $ORGS; do
  ccp+="  ${org}:
    mspid: $(echo "${org:0:1}" | tr '[:lower:]' '[:upper:]')${org:1}MSP
    peers:  
"
    
    while IFS=" " read -ra peer; do
      # orgs=
      ccp+="      - ${peer[1]}
"
    done < <(printf '%s\n' "$(grep "$org" <<< "$all_peers")")

  ccp+="    certificateAuthorities:
      - ca_$org
"
  done

}