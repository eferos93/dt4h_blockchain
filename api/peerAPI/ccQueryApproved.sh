#!/bin/bash


# Description: This script contains a function to query 
#              the approval status of a Hyperledger Fabric chaincode.

queryApproved() {
    
    printInfo "queryApproved - Querying approval status of CC ${CC_NAME} on channel ${CHANNEL_NAME}"

    # Execute the command to query the chaincode approval status and redirect output to log
    set -x
    peer lifecycle chaincode queryapproved -n ${CC_NAME} -C ${CHANNEL_NAME} >& log.txt
    res=$?
    set +x

    verifyResult "$res" "$(cat log.txt)" || printSuccess "queryApproved - Approved chaincode ${CC_NAME} for ${org}"
}
