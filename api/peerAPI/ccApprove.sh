#!/bin/bash
#
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# -----------------------------------------------------------------------------
# Description: This script contains a function to approve a specific chaincode 
#              for a given organization on the Hyperledger Fabric network.
# -----------------------------------------------------------------------------

approveCC() {		

	# Check if PACKAGE_ID is provided. If not, print an error message and terminate.
	if [[ -z "$PACKAGE_ID" ]]; then
		printError "approveCC - Package identifier not set. PACKAGE_ID"
		exit 1
	fi

	# Display information indicating the start of the chaincode approval process.
	printInfo "approveCC - Approving CC: ${CC_NAME}"
	
	# Execute the 'peer' command to initiate the chaincode approval process.
	set -x
	peer lifecycle chaincode approveformyorg \
		-o ${ORDERER} \
		--ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
		--tls \
		--cafile ${ORDERER_CAFILE} \
		-C ${CHANNEL_NAME} \
		--package-id ${PACKAGE_ID} \
		-n ${CC_NAME} \
		-v ${CC_VERSION} \
		--sequence ${CC_SEQUENCE}  \
		${CC_INIT_REQUIRED} >&log.txt 
	res=$?
	set +x

	# Check the outcome of the 'peer' command. If successful, print a success message.
	verifyResult "$res" "$(cat log.txt)" && printSuccess "approveCC - Approved chaincode ${CC_NAME} for ${org}"
}