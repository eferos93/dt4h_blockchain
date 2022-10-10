#!/bin/bash

# Check chaincode commit readiness 

checkCommitReadiness() {
	printInfo "checkCommitReadiness - Checking commit readiness of CC: ${CC_NAME}"

	local rc=1
	local COUNTER=1
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
		set -x
		peer lifecycle chaincode checkcommitreadiness -v ${CC_VERSION} -C ${CHANNEL_NAME} -n ${CC_NAME} --sequence ${CC_SEQUENCE} ${CC_INIT_REQUIRED} --output json >& log.txt
		res=$?
		set +x
		rc=$res
		COUNTER=$(expr $COUNTER + 1)
		cat log.txt
	done
	verifyResult "$res" "$(cat log.txt)"
}

# checkCommitReadiness