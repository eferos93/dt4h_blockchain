#!/bin/bash

# Main fabric directory
export FABRIC_HOME=${PWD}

##### Channel parameters

# Name of channel
export CHANNEL_NAME=dt4h

##### Set Chaincode Parameters

# Version of chaincode
# If the update is only for the endorsement policy, the version can stay the same
export CC_VERSION="1.0"

# Path to the chaincode
export CC_PATH=${FABRIC_HOME}/chaincode/dt4hCC

# Name of the chaincode package
export CC_NAME=dt4hCC

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
export PACKAGE_ID=dt4hCC_1.0:e587850fc64c544576c08b1ff67da189441a6aa6e74dff3dd600261db6b70065