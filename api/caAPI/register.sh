#!/bin/bash
#
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# Supported node types.
node_types="peer client orderer admin"

# Register function: Registers Peer to TLS and CA Servers
# Uses various environment variables like ORG_NAME, TYPE, USERNAME, SECRET, etc. 
# which need to be set before invoking this function.
register() {

    # Validate ORG_NAME environment variable.
    if [ -z "${ORG_NAME}" ]; then
        printError "register - No org specified."
        exit 1
    fi

    # Validate node type.
    validate_type "$TYPE"
    if [[ "$status" == false ]]; then 
        printError "register - No TYPE specified."
        exit 1
    fi

    # Validate USERNAME environment variable.
    if [ -z "$USERNAME" ]; then
        printError "register - No USERNAME specified"
        exit 1
    fi

    # Validate SECRET environment variable.
    if [ -z "$SECRET" ]; then
        printError "register - No enrollment secret specified." 
        exit 1
    fi

    printInfo "register - Registering ${ORG_NAME} ${TYPE} $USERNAME"

    # Set MSP directory paths.
    TLSMSPDIR="$FABRIC_CA_CLIENT_HOME"/tls-ca/${TLS_ADMIN}/msp
    # TLSOPSDIR=$FABRIC_CA_CLIENT_HOME/tlsops-ca/${TLS_ADMIN}/msp

    # Set attributes based on the type of the node.
    if [ "$TYPE" == "admin" ]; then
        attrs="--id.attrs hf.Registrar.Roles=*,hf.GenCRL=true,hf.Revoker=true"
    elif [ "$TYPE" == "peer" ]; then
        attrs="--id.attrs hf.GenCRL=true"
    else
        attrs=""
    fi

    # Register the node to CA Server.
    set -x
    fabric-ca-client register -M "$CAMSPDIR" -u https://"${CA_ENDPOINT}" --tls.certfiles "$TLS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET"  --caname "$CA_NAME" ${attrs}
    res=$?
    set +x 
    # Uncomment the below line to verify the result after registration.
    # verifyResult "$res" "Registration of peer to CA Server failed"

    # If USERS variable is not set, register to TLS Server and TLS Operations Server.
    if [ -z $USERS ]; then

        # Register the node to TLS Server.
        set -x
        fabric-ca-client register -M "$TLSMSPDIR" -u https://"${TLS_ENDPOINT}" --tls.certfiles "$TLS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET"  --caname "${TLS_CANAME}" ${attrs}
        res=$?
        set +x 
        # Uncomment the below line to verify the result after registration.
        # verifyResult "$res" "Registration of peer to TLS Server failed"

        printSuccess "register - ${ORG_NAME} ${USERNAME} registered successfully"
    fi
}

# Function to validate the node type.
# Sets the global variable 'status' to true if valid, false otherwise.
validate_type() {
    status=false
    input=$1

    # If input is empty, return.
    if [[ -z "$input" ]]; then
        return
    fi

    # Check if the input matches any of the supported node types.
    for type in $node_types; do
        if [[ "$input" == "$type" ]]; then
            status=true
            return
        fi
    done
}
