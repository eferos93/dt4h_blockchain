#!/bin/bash

# Query installed chaincode

queryInstalled() {

	printInfo "queryInstalled - Querying CC ${CC_NAME} for ${NODE_ID}.${ORG_NAME}..."

	set -x
	peer lifecycle chaincode queryinstalled ${CC_NAME}.tar.gz >& log.txt
	res=$?
	set +x
	verifyResult "$res" "$(cat log.txt)"

	export PACKAGE_ID=$(sed -n "/${CC_NAME}_${CC_VERSION}/{s/^Package ID: //; s/, Label:.*$//; p;}" log.txt)

	if [ ! "$PACKAGE_ID" ]; then
		verifyResult 1 "Package not found."
	fi

	sed -i -E "/^export PACKAGE_ID/s/=.*$/=${PACKAGE_ID}/g" "${FABRIC_HOME}"/configCC.sh
	
	[ "$res" -eq 0 ] && printSuccess "queryInstalled - Chaincode ${CC_NAME} is installed on ${NODE_ID}.${ORG_NAME}"
	echo "$PACKAGE_ID"
}
