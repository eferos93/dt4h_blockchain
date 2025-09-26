#!/bin/bash


# Description: This script contains a function to join a peer to a channel 
#              in a Hyperledger Fabric network.

# Join Peer to Channel (Admin only)
joinChannel() {
	printInfo "joinChannel - Joining peer ${NODE_ID}.${ORG_NAME} to channel ${CHANNEL_NAME}..."

	local rc=1
	local COUNTER=1
	local MAX_RETRY=2

	# Join channel	
	while [ $rc -ne 0 -a $COUNTER -ne $MAX_RETRY ]; do
		set -x 
		peer channel join -b ./channel-artifacts/${CHANNEL_NAME}.block >& log.txt 
		res=$?
		set +x
		rc=$res
		sleep 2
		COUNTER=$(expr $COUNTER + 1)	
	done

	verifyResult "$res" "$(cat log.txt)" && printSuccess "joinChannel - Peer ${NODE_ID}.${ORG_NAME} joined channel ${CHANNEL_NAME}"
}