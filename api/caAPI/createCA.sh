#!/bin/bash

# Create and Initialize the CA Server
createCAServer() {
	
	printInfo "createCAServer - Creating ${ORG_NAME} CA Servers..."

	if [ -d "$FABRIC_CA_SERVER_HOME" ]; then
		printError "createCAServer - Server for ${ORG_NAME} exists!"
		exit 1
	fi

	# Create the organization's CA Server directory
	mkdir -p "$FABRIC_CA_PATH"/"${ORG_NAME}"/fabric-ca-server-"${ORG_NAME}" organizations/fabric-ca docker

	# pushd
	cd "$FABRIC_CA_SERVER_HOME" || exit 1

	# Copy the fabric-ca-server binary to the CA Server dir
	mkdir tls
	mkdir -p users-ca/tls

	# The CA Admin has been enrolled at the creation of the TLS Server by the TLS Admin
	# and the keys and certs exist on the tls-ca/${CA_ADMIN}/msp folder so we need to copy
	# them to the server directory to enable TLS communication 
	
	cp ${FABRIC_CA_CLIENT_HOME}/tls-ca/${CA_ADMIN}/msp/signcerts/cert.pem tls && cp ${FABRIC_CA_CLIENT_HOME}/tls-ca/${CA_ADMIN}/msp/keystore/*.pem tls/key.pem
	cp ${FABRIC_CA_CLIENT_HOME}/tls-ca/${CA_ADMIN}/msp/signcerts/cert.pem users-ca/tls && cp ${FABRIC_CA_CLIENT_HOME}/tls-ca/${CA_ADMIN}/msp/keystore/*.pem users-ca/tls/key.pem

	# Initializing the server and bootstraping the CA Admin
	fabric-ca-server init -b ${CA_ADMIN}:${CA_ADMINPW} --cafiles users-ca/fabric-ca-server-config.yaml 
	cd users-ca
	fabric-ca-server init -b ${USERSCA_ADMIN}:${USERSCA_ADMINPW}
	cd ../

	# Importing our custom server config
	yes | cp "$FABRIC_CA_CFG_PATH"/base_ca_config.yaml ./fabric-ca-server-config.yaml

	# Check if org does not contain 'orderer', to add a users-ca
	set -x
	if [[ "${ORG_NAME}" != *"orderer"* ]]; then
		echo "$(yaml_ccp_fca_users ${ORG_NAME} $CA_PORT ${USERSCA_ADMIN} ${USERSCA_ADMINPW})" > ${FABRIC_CFG_PATH}/fca-usersca-${ORG_NAME}-config.yaml
		yes | cp "$FABRIC_CA_CFG_PATH"/fca-usersca-"${ORG_NAME}"-config.yaml users-ca/fabric-ca-server-config.yaml
	fi
	set +x
	
	# popd
	cd "$FABRIC_HOME" || exit

	##### IMPORTANT!!
	##### If the csr values on the fabric-ca-server-config.yaml 
	##### are changed, then the previous certificates must be 
	##### deleted and start the server to generate new ones.  
	# rm -rf $FABRIC_CA_SERVER_HOME/msp
	# rm $FABRIC_CA_SERVER_HOME/ca-cert.pem
	
	# Create Docker Files
	createDockerCA "${ORG_NAME}"
	export DOCK_COMPOSE_FILE=${DOCKER_HOME}/docker-compose-ca-${ORG_NAME}.yaml

	printSuccess "createCAServer - CA Server for ${ORG_NAME} initialized succesfully"
}


# Enroll the CA Admin to the CA Server
enrollCAAdmin() {
	printInfo "enrollCAAdmin - Enrolling the CA Admins..."

	# Enroll the CA Admin to obtain the msp 
	set -x
	fabric-ca-client enroll -u https://${CA_ADMIN}:${CA_ADMINPW}@"${CA_ENDPOINT}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --csr.hosts localhost,"${CA_HOST}" --mspdir "${ORG_NAME}"-ca/${CA_ADMIN}/msp --caname ca-${ORG_NAME}
	set +x
	res=$?
	verifyResult $res "enrollCAAdmin - Failed to enroll the CA Admin ${CA_ADMIN} to the CA Server at ${CA_ENDPOINT}"
	
	echo

	set -x
	fabric-ca-client enroll -u https://${USERSCA_ADMIN}:${USERSCA_ADMINPW}@"${CA_ENDPOINT}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --csr.hosts localhost,"${CA_HOST}" --mspdir "${ORG_NAME}"-users-ca/${USERSCA_ADMIN}/msp --caname ca-${ORG_NAME}-users
	set +x
	res=$?
	verifyResult $res "enrollCAAdmin - Failed to enroll the Users CA Admin ${USERSCA_ADMIN} to the CA Server at ${CA_ENDPOINT}"

	echo
	mv "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-ca/${CA_ADMIN}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-ca/${CA_ADMIN}/msp/keystore/key.pem
	mv "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-users-ca/${USERSCA_ADMIN}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-users-ca/${USERSCA_ADMIN}/msp/keystore/key.pem
	res=$?
	verifyResult $res "enrollCAAdmin - Failed to rename the CA Admin files"
	printSuccess "enrollCAAdmin - CA Admin: ${CA_ADMIN} (UsersCA Admin): ${USERSCA_ADMIN} enrolled successfully!"
}

createCA() {
	export FABRIC_CA_SERVER_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-ca-server-${ORG_NAME}
	export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-ca-client-${ORG_NAME}

	if [ -z "${ORG_NAME}" ]; then
		printError "createCA - Missing ORG_NAME"
		exit 1
	fi

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