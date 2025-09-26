#!/bin/bash


# Description: This script contains a function to commit the chaincode definition 
#              on a Hyperledger Fabric channel for a specific chaincode.

commitChaincodeDefinition() {

    # Set up the peers that the chaincode will be committed to
    setPeers 

    # Print informational message about the chaincode being committed
    printInfo "commitChaincodeDefinition - Committing CC ${CC_NAME} definition on channel ${CHANNEL_NAME}"

    # Initialize retry loop control variables
    local rc=1
    local COUNTER=1

    # Loop to retry the commit operation until it's successful or retry limit is reached
    while [ $rc -ne 0 -a $COUNTER -ne $MAX_RETRY ]; do

        # Execute the command to commit the chaincode definition, and redirect output to log
        set -x 
        peer lifecycle chaincode commit -C ${CHANNEL_NAME} ${PEERS} -o ${ORDERER} --cafile ${ORDERER_CAFILE} --sequence ${CC_SEQUENCE} -v ${CC_VERSION} -n ${CC_NAME} --tls --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} ${CC_INIT_REQUIRED}  >& log.txt
        res=$?
        set +x

        # Update control variables for retry loop
        rc=$res
        sleep 7
        COUNTER=$(expr $COUNTER + 1)    
    done

    verifyResult "$res" "$(cat log.txt)" && printSuccess "commitChaincodeDefinition - Chaincode ${CC_NAME} committed on channel ${CHANNEL_NAME}"
}
