#!/bin/bash

# Join Peer to Channel (Admin only)
joinChannel() {
	printInfo "joinChannel - Joining peer ${NODE_ID}.${ORG_NAME} to channel ${CHANNEL_NAME}..."

	local rc=1
	local COUNTER=1

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