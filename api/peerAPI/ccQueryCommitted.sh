#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script contains a function to query 
#              the commit status of a Hyperledger Fabric chaincode.

queryCommitted() {
    printInfo "queryCommitted - Querying commit status of CC ${CC_NAME}..."

    local rc=1
    local COUNTER=1
    while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
        set -x
        peer lifecycle chaincode querycommitted -n ${CC_NAME} -C ${CHANNEL_NAME} >& log.txt
        res=$?
        set +x
        rc=$res
        COUNTER=$(expr $COUNTER + 1)
    done

    verifyResult "$res" "$(cat log.txt)" && cat log.txt
}
