#!/bin/bash


# Description: This script provides functionality to sign a transaction

signConfigtxAsPeerOrg() {
	printInfo "signConfigtxAsPeerOrg - Signing the new config as ${NODE_ID}.${ORG_NAME}"

	if [ ! -f "${TX}" ]; then 
		printError "signConfigtxAsPeerOrg - File ${TX} not found"
		exit 1
	fi

	set -x
	peer channel signconfigtx -f "${TX}"
	res=$?
	set +x

	verifyResult "$res" "signConfigtxAsPeerOrg - Signing the transaction failed as ${NODE_ID} of ${org}" && printSuccess "signConfigtxAsPeerOrg - Transaction signed as ${NODE_ID}.${ORG_NAME}"
}

# signConfigTxAsPeerOrg