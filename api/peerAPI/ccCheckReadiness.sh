#!/bin/bash

# Description: This script contains a function to check the commit readiness 
#              of a specific chaincode on the Hyperledger Fabric network.

checkCommitReadiness() {

    # Print information about the chaincode being checked
    printInfo "checkCommitReadiness - Checking commit readiness of CC: ${CC_NAME}"

    # Initialize variables for retry logic
    local rc=1
    local COUNTER=1

    # Continue checking until the operation is successful or the retry limit is reached
    while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do

        # Execute the command to check the readiness of the chaincode and redirect output to log
        set -x
        peer lifecycle chaincode checkcommitreadiness -v ${CC_VERSION} -C ${CHANNEL_NAME} -n ${CC_NAME} --sequence ${CC_SEQUENCE} ${CC_INIT_REQUIRED} --output json >& log.txt
        res=$?
        set +x

        # Update control variables for retry loop
        rc=$res
        COUNTER=$(expr $COUNTER + 1)

        # Display the output of the command
        cat log.txt
    done

    verifyResult "$res" "$(cat log.txt)"
}
