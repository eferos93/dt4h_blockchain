#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script provides functionality to list channels for a peer 
#              in a Hyperledger Fabric network.

channelList() {
    printInfo "channelList - Listing channels for peer ${NODE_ID}.${ORG_NAME}"

    # List channels
    set -x
    peer channel list >& log.txt
    res=$?
    set +x

    verifyResult "$res" "$(cat log.txt)" && cat log.txt
}
