#!/bin/bash

# Submit proposal to create channel
channelList() {
	printInfo "channelList - Listing channels for peer ${NODE_ID}.${ORG_NAME}"

	# Create channel block
	set -x
	peer channel list >& log.txt
	res=$?
	set +x

	verifyResult "$res" "$(cat log.txt)" && cat log.txt
}

# createChannel