#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script provides functionality to submit a channel update 
#              transaction to a channel in a Hyperledger Fabric network.

channelUpdate() {
	printInfo "channelUpdate - Submitting channel update to ${CHANNEL_NAME}"
	
	pushd ${CHANNEL_ARTIFACTS}

	if [ ! -f "${TX}" ]; then 
		printError "channelUpdate - File ${TX} not found"
		exit 1
	fi
	
	set -x
	peer channel update -f "${TX}" -c ${CHANNEL_NAME} -o ${ORDERER} --cafile ${ORDERER_CAFILE} --tls --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} ${TLSHANDSHAKETIMESHIFT}
	res=$?
	set +x

	verifyResult "$res" "channelUpdate - Failed to submit channel update to ${CHANNEL_NAME}" && printSuccess "channelUpdate - Submitted channel update to ${CHANNEL_NAME} successfully"
}