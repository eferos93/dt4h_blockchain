#!/bin/bash
#
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# Create and initialize the TLS Server
createTLSServer() {
    if [ -d "$FABRIC_CA_SERVER_HOME" ]; then
        printError "TLS server for ${ORG_NAME} already exists."
        exit 1
    fi

    printInfo "Creating ${ORG_NAME} TLS Server..."
    
    # Create the TLS Server directory and initialize
    mkdir -p "$FABRIC_CA_SERVER_HOME" && cd "$FABRIC_CA_SERVER_HOME" || exit 1
    fabric-ca-server init -b ${TLS_ADMIN}:${TLS_ADMINPW}
    mv msp/keystore/*sk msp/keystore/rootkey.pem

    # Import existing and configured fabric-ca-server-config.yaml file
	echo "$(yaml_ccp_tlsca ${ORG_NAME} $TLS_PORT ${TLS_ADMIN} ${TLS_ADMINPW})" > ${FABRIC_CA_CFG_PATH}/tlsca-${ORG_NAME}-config.yaml
	ORG_CONFIG="${FABRIC_CA_CFG_PATH}/tlsca-${ORG_NAME}-config.yaml"
    cp "$ORG_CONFIG" ./fabric-ca-server-config.yaml || {
        printError "Failed to copy config"
        exit 1
    }

    cd "$FABRIC_HOME" || exit 1
    createDockerTLSCA "${ORG_NAME}"
    export DOCK_COMPOSE_FILE=${DOCKER_HOME}/docker-compose-tls-${ORG_NAME}.yaml

    printSuccess "TLS Server for ${ORG_NAME} initialized successfully."
    sleep 5
}


# When the server is up, enroll the TLS Admin to obtain the key and TLS cert to enable communication 
createTLSClient() {
	printInfo "createTLSClient - Creating the TLS Client..."

	# Create directory for the client
	mkdir -p "${FABRIC_CA_CLIENT_HOME}"
	cd "$FABRIC_CA_CLIENT_HOME" || exit 1
	
	# Directory to store the certificates that are issued upon enrolling 
	# the boostrap identity 
	mkdir tls-ca

	# Directory to store the TLS CA root certificate to allow 
	# communication with the TLS CA Server (tls-ca-cert.pem)
	mkdir tls-root-cert
	
	# Directory to store the files of the organization when 
	# creating the CA Server
	mkdir "${ORG_NAME}"-ca 

	# Copy ca-cert.pem to the client folder 
	cp "$FABRIC_CA_SERVER_HOME"/ca-cert.pem "$FABRIC_CA_CLIENT_HOME"/tls-root-cert/tls-ca-cert.pem

	# Enroll the TLS CA admin user to issue keys and certs
	printInfo "createTLSClient - Enrolling the TLS CA Admin: ${TLS_ADMIN}"
	set -x
	fabric-ca-client enroll -u https://${TLS_ADMIN}:${TLS_ADMINPW}@"${TLS_ENDPOINT}" --csr.hosts ${TLS_HOST},tlsca_"${ORG_NAME}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --enrollment.profile tls --mspdir tls-ca/${TLS_ADMIN}/msp 
	res=$?
	set +x
	verifyResult $res "createTLSClient - Failed to enroll identity ${TLS_ADMIN}"

	mv "$FABRIC_CA_CLIENT_HOME"/tls-ca/${TLS_ADMIN}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/tls-ca/${TLS_ADMIN}/msp/keystore/key.pem
	verifyResult "$?" "createTLSClient - Failed to rename key"

	cd "$FABRIC_HOME" || exit 1
	printSuccess "createTLSClient - TLS Client admin ${TLS_ADMIN} enrolled successfully!"
}


# Register and Enroll the CA Admin via the TLS CA Admin to issue keys and certs to the TLS Server
enrollTLSCAAdmin() {
	printInfo "enrollTLSCAAdmin - Registering ${ORG_NAME} TLS CA Admin..."

	setParams "${ORG_NAME}"

	# Register CA Admin to the TLS CA via the TLS CA Admin
	cd "$FABRIC_CA_CLIENT_HOME" || exit 1

	set -x
	fabric-ca-client register --id.name ${CA_ADMIN} --id.secret ${CA_ADMINPW} -u https://"${TLS_ENDPOINT}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --mspdir tls-ca/${TLS_ADMIN}/msp
	res=$?
	set +x
	verifyResult $res "enrollTLSCAAdmin - Failed to register the CA Admin ${CA_ADMIN} to the TLS Server" || printSuccess "enrollTLSCAAdmin - CA Admin ${CA_ADMIN} registered to the TLS Server successfully"

	# Enroll CA Admin to obtain keys and certificates
	printInfo "enrollTLSCAAdmin - Enrolling the CA Admin: ${CA_ADMIN}"
	set -x
	fabric-ca-client enroll -u https://${CA_ADMIN}:${CA_ADMINPW}@"${TLS_ENDPOINT}" --csr.hosts ${TLS_HOST} --tls.certfiles tls-root-cert/tls-ca-cert.pem --enrollment.profile tls --mspdir tls-ca/${CA_ADMIN}/msp 
	set +x

	# Rename the secret key to key.pem for easier manipulation
	mv "$FABRIC_CA_CLIENT_HOME"/tls-ca/${CA_ADMIN}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/tls-ca/${CA_ADMIN}/msp/keystore/key.pem
	verifyResult $? "enrollTLSCAAdmin - Failed to enroll the CA Admin ${CA_ADMIN} to the TLS Server" || printSuccess "enrollTLSCAAdmin - CA Admin ${CA_ADMIN} enrolled successfully"
	
	cd "$FABRIC_HOME" || exit 1
	sleep 3
}

createTLSCA() {
	export FABRIC_CA_SERVER_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-tlsca-server-${ORG_NAME}
	export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-ca-client-${ORG_NAME}

	if [ -z "${ORG_NAME}" ]; then
		printError "createTLSCA - Missing ORG_NAME"
		exit 1
	fi
	
	mkdir -p $FABRIC_CA_PATH

	createTLSServer
	startServer
	mv ${FABRIC_CA_SERVER_HOME}/msp/keystore/*sk ${FABRIC_CA_SERVER_HOME}/msp/keystore/tlskey.pem

	createTLSClient  	
	enrollTLSCAAdmin 

	printSuccess "createTLSCA - TLS Server-Client for ${ORG_NAME} created successfully!"

}
