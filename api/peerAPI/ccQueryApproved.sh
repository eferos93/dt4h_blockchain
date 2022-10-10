#!/bin/bash

# Query approved chaincode

queryApproved() {
	printInfo "queryApproved - Querying approval status of CC ${CC_NAME} on channel ${CHANNEL_NAME}"

	set -x
	peer lifecycle chaincode queryapproved -n ${CC_NAME} -C ${CHANNEL_NAME} >& log.txt
	res=$?
	set +x

	verifyResult "$res" "$(cat log.txt)" || printSuccess "queryApproved - Approved chaincode ${CC_NAME} for ${org}"
}

# queryApproved