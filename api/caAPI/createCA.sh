#!/bin/bash
#
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# Create and Initialize the CA Server for a given ORG_NAME.
createCAServer() {
    printInfo "createCAServer - Creating ${ORG_NAME} CA Servers..."

    # Exit if CA Server for the organization already exists.
    if [ -d "$FABRIC_CA_SERVER_HOME" ]; then
        printError "createCAServer - Server for ${ORG_NAME} exists!"
        exit 1
    fi

    # Initialize directory structure.
    mkdir -p "$FABRIC_CA_PATH"/"${ORG_NAME}"/fabric-ca-server-"${ORG_NAME}" organizations/fabric-ca docker
    cd "$FABRIC_CA_SERVER_HOME" || exit 1

    # Set up the directory for TLS and User CA.
    mkdir tls
    mkdir -p users-ca/tls

    # Copy the TLS certs for enabling TLS communication.
    cp ${FABRIC_CA_CLIENT_HOME}/tls-ca/${CA_ADMIN}/msp/signcerts/cert.pem tls 
    cp ${FABRIC_CA_CLIENT_HOME}/tls-ca/${CA_ADMIN}/msp/keystore/*.pem tls/key.pem
    cp ${FABRIC_CA_CLIENT_HOME}/tls-ca/${CA_ADMIN}/msp/signcerts/cert.pem users-ca/tls 
    cp ${FABRIC_CA_CLIENT_HOME}/tls-ca/${CA_ADMIN}/msp/keystore/*.pem users-ca/tls/key.pem

    # Initialize the CA server.
    fabric-ca-server init -b ${CA_ADMIN}:${CA_ADMINPW} --cafiles users-ca/fabric-ca-server-config.yaml 
    cd users-ca
    fabric-ca-server init -b ${USERSCA_ADMIN}:${USERSCA_ADMINPW}
    cd ..

    # Add the org's configuration on the org's fabric ca folder
    echo "$(yaml_ccp_ca ${ORG_NAME} $CA_PORT ${CA_ADMIN} ${CA_ADMINPW})" > ${FABRIC_CA_CFG_PATH}/ca-${ORG_NAME}-config.yaml
    yes | cp "${FABRIC_CA_CFG_PATH}"/ca-"${ORG_NAME}"-config.yaml ./fabric-ca-server-config.yaml

    # if [[ "${ORG_NAME}" != *"orderer"* ]]; then
    #     echo "$(yaml_ccp_fca_users ${ORG_NAME} $CA_PORT ${USERSCA_ADMIN} ${USERSCA_ADMINPW})" > ${FABRIC_CFG_PATH}/fca-usersca-${ORG_NAME}-config.yaml
    #     yes | cp "$FABRIC_CA_CFG_PATH"/fca-usersca-"${ORG_NAME}"-config.yaml users-ca/fabric-ca-server-config.yaml
    # fi
    
    # Return to main directory.
    cd "$FABRIC_HOME" || exit

    # Set up Docker containers for CA.
    createDockerCA "${ORG_NAME}"
    export DOCK_COMPOSE_FILE=${DOCKER_HOME}/docker-compose-ca-${ORG_NAME}.yaml

    printSuccess "createCAServer - CA Server for ${ORG_NAME} initialized succesfully"
}

# Enroll the CA Admin with the CA Server.
enrollCAAdmin() {
    printInfo "enrollCAAdmin - Enrolling the CA Admins..."

    # Enroll main CA admin.
    fabric-ca-client enroll -u https://${CA_ADMIN}:${CA_ADMINPW}@"${CA_ENDPOINT}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --csr.hosts localhost,"${CA_HOST}" --mspdir "${ORG_NAME}"-ca/${CA_ADMIN}/msp --caname ca-${ORG_NAME}
    res=$?
    verifyResult $res "enrollCAAdmin - Failed to enroll the CA Admin ${CA_ADMIN} to the CA Server at ${CA_ENDPOINT}"

    # Enroll Users CA admin.
    fabric-ca-client enroll -u https://${USERSCA_ADMIN}:${USERSCA_ADMINPW}@"${CA_ENDPOINT}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --csr.hosts localhost,"${CA_HOST}" --mspdir "${ORG_NAME}"-users-ca/${USERSCA_ADMIN}/msp --caname ca-${ORG_NAME}-users
    res=$?
    verifyResult $res "enrollCAAdmin - Failed to enroll the Users CA Admin ${USERSCA_ADMIN} to the CA Server at ${CA_ENDPOINT}"

    # Rename key files for better identification.
    mv "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-ca/${CA_ADMIN}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-ca/${CA_ADMIN}/msp/keystore/key.pem
    mv "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-users-ca/${USERSCA_ADMIN}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-users-ca/${USERSCA_ADMIN}/msp/keystore/key.pem
    res=$?
    verifyResult $res "enrollCAAdmin - Failed to rename the CA Admin files"

    printSuccess "enrollCAAdmin - CA Admin: ${CA_ADMIN} (UsersCA Admin): ${USERSCA_ADMIN} enrolled successfully!"
}

# Main function to create a Certificate Authority for the organization.
createCA() {
    export FABRIC_CA_SERVER_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-ca-server-${ORG_NAME}
    export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-ca-client-${ORG_NAME}

    # Check for required environment variables.
    if [ -z "${ORG_NAME}" ]; then
        printError "createCA - Missing ORG_NAME"
        exit 1
    fi

    # Steps to set up CA for the organization.
    printHead "createCA - Create CA Server for ${ORG_NAME}"
    createCAServer
    printHead "createCA - Bring up ${ORG_NAME} CA Server"
    startServer
    yes | mv ${FABRIC_CA_SERVER_HOME}/msp/keystore/*sk ${FABRIC_CA_SERVER_HOME}/msp/keystore/rootkey.pem
    yes | mv ${FABRIC_CA_SERVER_HOME}/users-ca/msp/keystore/*sk ${FABRIC_CA_SERVER_HOME}/users-ca/msp/keystore/rootkey.pem
    printHead "createCA - Create CA Client for ${ORG_NAME}"
    enrollCAAdmin
    printSuccess "createCA - CA Server-Client created successfully!"
}

