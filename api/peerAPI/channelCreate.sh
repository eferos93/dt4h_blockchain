#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script contains a function to create a new channel 
#              in a Hyperledger Fabric network.

createChannel() {
    printInfo "createChannel - Creating channel ${CHANNEL_NAME}"

    # Create channel block
    set -x
    peer channel create -c ${CHANNEL_NAME} -f ./channel-artifacts/${CHANNEL_NAME}.block --cafile ${ORDERER_CAFILE} -o ${ORDERER} --tls --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} --outputBlock ./channel-artifacts/${CHANNEL_NAME}.block >& log.txt
    res=$?
    set +x

    verifyResult "$res" "$(cat log.txt)" && printSuccess "createChannel - Channel Block for ${CHANNEL_NAME} created!"
}
