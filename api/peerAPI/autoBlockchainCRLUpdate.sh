#!/bin/bash
#
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# -----------------------------------------------------------------------------
# Script Description:
# This script contains functions to update revoked certificates on the blockchain
# using the Certificate Revocation List (CRL). It continually checks for the 
# presence of a CRL and, if found, updates the blockchain accordingly.
# -----------------------------------------------------------------------------

# Function: updateBlockchainRevokedCertificates
# Description: Continuously updates the blockchain with any new revoked certificates 
#              found in the Certificate Revocation List (CRL).
updateBlockchainRevokedCertificates() {
	# Initialize parameters and environment variables
	setParams "$ORG_NAME"
	export NO_SAVE_LOG=TRUE

	# Infinite loop to continuously check and update the CRL
	while :
	do
		invokeUpdateCRL

		# Sleep for 20 seconds before checking again
		sleep 20
	done
}

# Function: invokeUpdateCRL
# Description: Checks for the presence of a CRL and, if found, invokes the blockchain
#              to update the list of revoked certificates.
invokeUpdateCRL() {
	# Define path to the Certificate Revocation List (CRL)
	CRL_PATH="${CHANNEL_ARTIFACTS}/crls/crl.pem" 
	
	# Exit function if CRL file doesn't exist
	if [ ! -f ${CRL_PATH} ]; then
		return
	fi

	# Initialize an empty string to hold the CRL content
	CRL_STRING=
	# Read each line of the CRL and append it to the CRL_STRING with newline characters
	while IFS= read -r line
	do
		CRL_STRING+="${line}\\n"
	done < "$CRL_PATH"

	# Define the function call to the blockchain management contract to update the CRL
	funcCall='{"Args":["ManagementContract:UpdateCRL","'"${CRL_STRING}"\"]}
	
	# Use the peer.sh script to invoke the update on the blockchain
	./peer.sh invoke -x "${funcCall}" -n peer0.${ORG_NAME}.dt4h.com
}
