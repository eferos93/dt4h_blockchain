#!/bin/bash

identityList() {
	printInfo "identityList - Listing Identities of ${ORG_NAME}"

	if [ -z "${ORG_NAME}" ]; then
		printError "identityList - No org specified"
		exit 1
	fi

	setParams "${ORG_NAME}"
	
	if [ $TLS ]; then
		set -x
		fabric-ca-client identity list --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${tlsendpoint} -M ./tls-ca/${tlsadmin}/msp
		res=$?
		set +x
		verifyResult "$res" "identityList - Failed to get identities"
	else	
		if [[ $USERS ]]; then
			echo "$USERS"
			set -x
			fabric-ca-client identity list --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${caendpoint} -M ./${ORG_NAME}-users-ca/${userscaadmin}/msp/ --caname ${caName}-users
			res=$?
			set +x
		else 
			set -x
			fabric-ca-client identity list --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${caendpoint} -M ./${ORG_NAME}-ca/${caadmin}/msp/ 
			res=$?
			set +x
		fi
		
		verifyResult "$res" "identityList - Failed to get identities"
	fi
	
}