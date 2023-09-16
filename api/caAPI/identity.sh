#!/bin/bash

identityList() {
	printInfo "identityList - Listing Identities of ${ORG_NAME}"

	if [ -z "${ORG_NAME}" ]; then
		printError "identityList - No org specified"
		exit 1
	fi

	if [ $TLS ]; then
		set -x
		fabric-ca-client identity list --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${TLS_ENDPOINT} -M ./tls-ca/${TLS_ADMIN}/msp
		res=$?
		set +x
		verifyResult "$res" "identityList - Failed to get identities"
	else	
		if [[ $USERS ]]; then
			set -x
			fabric-ca-client identity list --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${CA_ENDPOINT} -M ./${ORG_NAME}-users-ca/${USERSCA_ADMIN}/msp/ --caname ${CA_NAME}
			res=$?
			set +x
		else 
			set -x
			fabric-ca-client identity list --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${CA_ENDPOINT} -M ./${ORG_NAME}-ca/${CA_ADMIN}/msp/ 
			res=$?
			set +x
		fi
		
		verifyResult "$res" "identityList - Failed to get identities"
	fi
	
}

identityModify() {
	printInfo "identityModify - Modifying identity of ${ORG_NAME}"

	if [ -z "${ORG_NAME}" ]; then
		printError "identityModify - No org specified"
		exit 1
	fi

	if [ $TLS ]; then
		set -x
		fabric-ca-client identity modify ${USERNAME}  --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${TLS_ENDPOINT} -M ./tls-ca/${TLS_ADMIN}/msp
		res=$?
		set +x
		verifyResult "$res" "identityModify - Failed to get identities"
	else	
		if [[ $USERS ]]; then
			set -x
			fabric-ca-client identity modify  ${USERNAME} --id.attrs hf.Registrar.Roles=*  --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${CA_ENDPOINT} -M ./${ORG_NAME}-users-ca/${USERSCA_ADMIN}/msp/ --caname ${CA_NAME}
			res=$?
			set +x
		else 
			set -x
			fabric-ca-client identity modify  ${USERNAME} --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${CA_ENDPOINT} -M ./${ORG_NAME}-ca/${CA_ADMIN}/msp/ 
			res=$?
			set +x
		fi
		
		verifyResult "$res" "identityModify - Failed to get identities"
	fi
	
}