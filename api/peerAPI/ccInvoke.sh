#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script contains a function to invoke a transaction 
#              on a Hyperledger Fabric chaincode.

invoke() {

    printInfo "invoke - Invoking ${CC_NAME}"

    set -x
    peer chaincode invoke -c "${TX}" -C ${CHANNEL_NAME} -n ${CC_NAME} -o ${ORDERER} --cafile ${ORDERER_CAFILE} --tls --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} >& log.txt
    res=$?
    set +x

    verifyResult "$res" "$(cat log.txt)" || printSuccess "$(cat log.txt)"
}
