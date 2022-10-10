#!/bin/bash

# Approve chaincode

approveCC() {		

	if [[ -z "$PACKAGE_ID" ]]; then
		printError "approveCC - Package identifier not set. PACKAGE_ID"
		exit 1
	fi

	printInfo "approveCC - Approving CC: ${CC_NAME}"
	
	set -x
	peer lifecycle chaincode approveformyorg -o ${ORDERER} --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} --tls --cafile ${ORDERER_CAFILE} -C ${CHANNEL_NAME} --package-id ${PACKAGE_ID} -n ${CC_NAME} -v ${CC_VERSION} --sequence ${CC_SEQUENCE}  ${CC_INIT_REQUIRED} >&log.txt 
	res=$?
	set +x

	verifyResult "$res" "$(cat log.txt)" && printSuccess "approveCC - Approved chaincode ${CC_NAME} for ${org}"
}

# approveCC 