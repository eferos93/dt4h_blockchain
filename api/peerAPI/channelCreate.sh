#!/bin/bash

# Submit proposal to create channel
createChannel() {
	printInfo "createChannel - Creating channel ${CHANNEL_NAME}"

	# Create channel block
	set -x
	peer channel create -c ${CHANNEL_NAME} -f ./channel-artifacts/${CHANNEL_NAME}.tx --cafile ${ORDERER_CAFILE} -o ${ORDERER} --tls --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block >& log.txt
	res=$?
	set +x

	verifyResult "$res" "$(cat log.txt)" && printSuccess "createChannel - Channel Block for ${CHANNEL_NAME} created!"
}

# createChannel