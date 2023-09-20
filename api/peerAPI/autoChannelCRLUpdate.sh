#!/bin/bash
#
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# -----------------------------------------------------------------------------
# Script Description:
# This script contains functions to generate and update the Certificate Revocation List (CRL)
# on the blockchain. It automates the process of fetching the CRL, converting it to 
# base64 format, and updating the channel configuration on the blockchain.
# -----------------------------------------------------------------------------

# Function: updateCRL
# Description: Continuously generates the CRL and updates the channel configuration
#              on the blockchain.
updateCRL() {
	# Initialize parameters and environment variables
	setParams "$ORG_NAME"
	export NO_SAVE_LOG=TRUE

	# Infinite loop to continuously generate and update CRL
	while :
	do
		getCRL
		updateChannelConfig

		# Sleep for 10 seconds before the next iteration
		sleep 10
	done
}

# Function: getCRL
# Description: Generates the CRL, moves it to the CHANNEL_ARTIFACTS directory,
#              and then converts it from PEM format to base64.
getCRL() {
	# Generate CRL using the clientCA script
	. clientCA.sh gencrl 

	# Define the path to save the generated CRL
	export CRL_PATH="${CAMSPDIR}/crls"
	mkdir -p "${CHANNEL_ARTIFACTS}" "$CRL_PATH"

	# Synchronize the generated CRL to the CHANNEL_ARTIFACTS directory
	set -x
	rsync -a "${CRL_PATH}" "${CHANNEL_ARTIFACTS}/"
	set +x
	res=$?
	# Verify if the operation was successful
	verifyResult "$res" "getCRL - Failed to move CRL to ${CHANNEL_ARTIFACTS}"

	# Convert the CRL from PEM format to base64 and save it
	set -x
	base64 -w 0 "${CHANNEL_ARTIFACTS}/crls/crl.pem" > "${CHANNEL_ARTIFACTS}/crl64"
	set +x
	res=$?
	# Verify if the conversion was successful
	verifyResult "$res" "getCRL - Failed to convert crl.pem to base64"
}

# Function: updateChannelConfig
# Description: Automates the process of fetching the channel configuration,
#              updating the CRL, and then pushing the updated configuration 
#              to the blockchain.
updateChannelConfig() {
	# Fetch the channel configuration
	./peer.sh fetchconfig -n peer0.${ORG_NAME}.domain.com
	
	# Update the CRL in the channel configuration
	./peer.sh crlupdate -O ${ORG_MSPID}

	# Push the updated channel configuration to the blockchain
	./peer.sh channelupdate -n peer0.${ORG_NAME}.domain.com -A
	res=$?
	# Verify if the channel update was successful
	verifyResult "$res" "updateChannelConfig - Error computing channel update"
}
