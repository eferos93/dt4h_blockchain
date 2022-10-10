#!/bin/bash

# Check chaincode commit readiness 

commitChaincodeDefinition() {
	setPeers 
	printInfo "commitChaincodeDefinition - Committing CC ${CC_NAME} definition on channel ${CHANNEL_NAME}"

	local rc=1
	local COUNTER=1

	# Join channel	
	while [ $rc -ne 0 -a $COUNTER -ne $MAX_RETRY ]; do
		set -x 
		peer lifecycle chaincode commit -C ${CHANNEL_NAME} ${PEERS} -o ${ORDERER} --cafile ${ORDERER_CAFILE} --sequence ${CC_SEQUENCE} -v ${CC_VERSION} -n ${CC_NAME} --tls --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} ${CC_INIT_REQUIRED}  >& log.txt
		res=$?
		set +x
		rc=$res
		sleep 7
		COUNTER=$(expr $COUNTER + 1)	
	done

	verifyResult "$res" "$(cat log.txt)" && printSuccess "commitChaincodeDefinition - Chaincode ${CC_NAME} committed on channel ${CHANNEL_NAME}"
}

# commitChaincodeDefinition