#!/bin/bash

# Install chaincode on peer

# Admin operation 
installCC() {
	printInfo "installCC - Installing CC ${CC_NAME} on ${NODE_ID}.${ORG_NAME}..."

	set -x
	peer lifecycle chaincode install ${CC_NAME}.tar.gz >& log.txt
	res=$?
	set +x

	verifyResult "$res" "$(cat log.txt)" && printSuccess "installCC - Chaincode ${CC_NAME} is installed on ${NODE_ID}.${ORG_NAME}"
}

# installCC