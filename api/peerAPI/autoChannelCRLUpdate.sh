#!/bin/bash

updateCRL() {
	# Init
	setParams "$ORG_NAME"
	export NO_SAVE_LOG=TRUE

	while :
	do
		getCRL
		updateChannelConfig

		sleep 10
	done
}

getCRL() {
	# Generate CRL
	. clientCA.sh gencrl 

	export CRL_PATH="${CAMSPDIR}/crls"
	mkdir -p "${CHANNEL_ARTIFACTS}" "$CRL_PATH"

	set -x
	# Move CRL to CHANNEL_ARTIFACTS dir
	rsync -a "${CRL_PATH}" "${CHANNEL_ARTIFACTS}/"
	set +x
	res=$?
	verifyResult "$res" "getCRL - Failed to move CRL to ${CHANNEL_ARTIFACTS}"

	# Decode PEM to base64
	set -x
	base64 -w 0 "${CHANNEL_ARTIFACTS}/crls/crl.pem" > "${CHANNEL_ARTIFACTS}/crl64"
	res=$?
	set +x
	verifyResult "$res" "getCRL - Failed to convert crl.pem to base64"
}

updateChannelConfig() {

	./peer.sh fetchconfig -n peer0.${ORG_NAME}.domain.com
	./peer.sh crlupdate -O ${ORG_MSPID}
	./peer.sh channelupdate -n peer0.${ORG_NAME}.domain.com -A
	res=$?
	verifyResult "$res" "updateChannelConfig - Error computing channel update"
}
