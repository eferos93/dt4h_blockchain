#!/bin/bash


updateBlockchainRevokedCertificates() {
	# Init
	setParams "$ORG_NAME"
	export NO_SAVE_LOG=TRUE

	while :
	do
		invokeUpdateCRL

		sleep 20
	done
}


invokeUpdateCRL() {

	CRL_PATH="${CHANNEL_ARTIFACTS}/crls/crl.pem" 
	
	# Check CRL Exists
	if [ ! -f ${CRL_PATH} ]; then
		return
	fi

	CRL_STRING=
	while IFS= read -r line
	do
		CRL_STRING+="${line}\\n"
	done < "$CRL_PATH"

	funcCall='{"Args":["ManagementContract:UpdateCRL","'"${CRL_STRING}"\"]}

	./peer.sh invoke -x "${funcCall}" -n peer0.${ORG_NAME}.domain.com
}


