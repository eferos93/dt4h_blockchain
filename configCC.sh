#!/bin/bash

# Main fabric directory
export FABRIC_HOME=${PWD}

##### Channel parameters

# Name of channel
export CHANNEL_NAME=agora

##### Set Chaincode Parameters

# Version of chaincode
# If the update is only for the endorsement policy, the version can stay the same
export CC_VERSION="1.0"

# Path to the chaincode
export CC_PATH=${FABRIC_HOME}/chaincode/agoraCC

# Name of the chaincode package
export CC_NAME=agoraCC

# Should be incremented by 1 on every chaincode update commit
export CC_SEQUENCE=1

# Endorsement policy
export CC_EP="NA"

# Validation policy
export CC_VP="NA"

# Language of chaincode
# CC_RUNTIME_LANGUAGE=

# If chaincode needs to be initialized upon committment
# CC_INIT_REQUIRED="--init-required"
# Timeout and retries on connecting to the orderer
export CONN_TIMEOUT=3
export MAX_RETRY=10

# Package IDentifier
export PACKAGE_ID=agoraCC_1.0:1eeffcacf1ceef9de5f8cc0e45d873500b288d3b5b8cd0bda57e6574c8965e72