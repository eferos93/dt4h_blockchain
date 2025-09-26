#!/bin/bash


##########################
# Reenroll the node to obtain the MSP (Membership Service Provider) credentials.
# Globals:
#   ORG_NAME, TYPE, USERNAME, SECRET, FABRIC_HOME, CA_TYPE, 
#   REUSE_KEY, TLS_ENDPOINT, TLS_ROOTCERT_PATH, caendpoint
# Arguments:
#   None
# Returns:
#   None
##########################
reenroll() {
    printInfo "reenroll - Reenrolling ${ORG_NAME} ${TYPE}..."

    # Check for the existence of the organization
    if [ -z "${ORG_NAME}" ]; then
        printError "reenroll - No org specified"
        exit 1
    fi

    # Validate the type of the node (peer/orderer)
    validate_type "$TYPE"
    if [[ "$status" == false ]]; then 
        printError "reenroll - No TYPE specified"
        exit 1
    fi

    # Check for the existence of a username
    if [ -z "$USERNAME" ]; then
        printError "reenroll - No username specified"
        exit 1
    fi

    # Ensure user has root permissions
    is_user_root

    # Determine the home directory of the node
    NODE_HOME=$FABRIC_HOME/organizations/${typeOfOrg}Organizations/${ORG_NAME}.dt4h.com/users/"$USERNAME"
    
    # Adjust home directory based on the node type
    if [[ "$TYPE" == "peer" ]]; then
        NODE_HOME=$FABRIC_HOME/organizations/peerOrganizations/${ORG_NAME}.dt4h.com/"$TYPE"s/"$USERNAME".${ORG_NAME}.dt4h.com
    elif [[ "$TYPE" == "orderer" ]]; then
        NODE_HOME=$FABRIC_HOME/organizations/ordererOrganizations/${ORG_NAME}.dt4h.com/"$TYPE"s/"$USERNAME".${ORG_NAME}.dt4h.com
    fi

    # Determine the directories to store MSP data
    CAMSPDIR=$NODE_HOME/msp
    TLSMSPDIR=$NODE_HOME/tls
    OLDMSPSDIR=$NODE_HOME/oldmsps

    # Initialize the necessary directories
    [ ! -d "$NODE_HOME" ] && mkdir -p "$NODE_HOME"
    [ -d "$CAMSPDIR" ] && [ ! -d "$OLDMSPSDIR" ] && mkdir -p "$OLDMSPSDIR"
    [ -d "$OLDMSPSDIR" ] && msp_no="$(ls "$OLDMSPSDIR" | wc -l)" && mkdir -p "$OLDMSPSDIR"/$msp_no

    # Display reenrollment target
    [ -z $CA_TYPE ] && printInfo "Reenrolling to all CAs" || printInfo "Reenrolling to ${CA_TYPE^^} CA"
    
    # Handle reenrollment for TLS
    if [ -z "$CA_TYPE" ] || [ "$CA_TYPE" == 'tls' ]; then
        # Backup old MSP data
        [ -d "$TLSMSPDIR" ] && cp -r "$TLSMSPDIR" "$OLDMSPSDIR"/$msp_no
        set -x
        fabric-ca-client reenroll -d ${REUSE_KEY} -M "$TLSMSPDIR" -u https://"${TLS_ENDPOINT}" --enrollment.profile tls --tls.certfiles "$TLS_ROOTCERT_PATH" --csr.hosts localhost,"$USERNAME"."${ORG_NAME}".dt4h.com,tlsca_"${ORG_NAME}"
        res=$?
        set +x
        verifyResult "$res" "reenroll - Failed to enroll $TYPE $USERNAME to TLS Server"
        
        # Update the key/cert files
        if [ -z ${REUSE_KEY} ]; then
            rm "$TLSMSPDIR"/keystore/key.pem
            mv "$TLSMSPDIR"/keystore/* "$TLSMSPDIR"/keystore/key.pem
            rm "$TLSMSPDIR"/tlscacerts/ca.crt
            mv "$TLSMSPDIR"/tlscacerts/* "$TLSMSPDIR"/tlscacerts/ca.crt
        fi
    fi

    # Handle reenrollment for CA
    if [ -z "$CA_TYPE" ] || [ "$CA_TYPE" == 'ca' ]; then
        [ -d "$CAMSPDIR" ] && cp -r "$CAMSPDIR" "$OLDMSPSDIR"/$msp_no
        set -x 
        fabric-ca-client reenroll -d ${REUSE_KEY}  -M "$CAMSPDIR" -u https://"$caendpoint" --tls.certfiles "$TLS_ROOTCERT_PATH" --csr.hosts localhost,"$USERNAME"."${ORG_NAME}".dt4h.com,ca_"${ORG_NAME}"
        res=$?
        set +x
        verifyResult "$res" "reenroll - Failed to enroll $TYPE $USERNAME to CA Server"
        
        # Update the key/cert files
        if [ -z ${REUSE_KEY} ]; then
            rm "$CAMSPDIR"/keystore/key.pem
            rm "$CAMSPDIR"/cacerts/cacert.pem
            mv "$CAMSPDIR"/keystore/* "$CAMSPDIR"/keystore/key.pem
            mv "$CAMSPDIR"/cacerts/* "$CAMSPDIR"/cacerts/cacert.pem
            cp -R "$TLSMSPDIR"/tlscacerts "$CAMSPDIR"/
        fi
    fi

    # Generate config.yaml with necessary Node OUs
    createNodeOUs "$CAMSPDIR"
    printSuccess "reenroll - ${ORG_NAME} $TYPE: $USERNAME reenrolled successfully"
}

