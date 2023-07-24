#!/bin/bash

# Create Channel TX

# Create channel config transaction
createChannelTx() {
	printInfo "createChannelTx - Creating channel tx..."

	which configtxgen
	if [ "$?" -ne 0 ]; then
		printError "createChannelTx - Configtxgen tool not found."
		return
	fi
	
	# Create channel tx block
	set -x
	mkdir channel-artifacts
	echo $FABRIC_CFG_PATH
	configtxgen -profile ${CHANNEL_PROFILE} -channelID ${CHANNEL_NAME} -configPath "$FABRIC_CFG_PATH" -outputBlock ./channel-artifacts/${CHANNEL_NAME}.block
	res=$?
	set +x

	verifyResult "$res" "createChannelTx - Channel Tx generation failed!" && printSuccess "createChannelTx - Channel Tx created!"
}

# createChannelTx