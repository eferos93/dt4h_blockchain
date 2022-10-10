#!/bin/bash

# TLS
createTLSOpsServer() {
	if [ -d "$FABRIC_CA_SERVER_HOME" ]; then
		printError "Server exists"
		exit 1
	fi
	
	setParams "${ORG_NAME}"
	printInfo "createTLSOpsServer - Creating ${ORG_NAME} TLS Operations Server..."

	# User Input

	# Read user input
	# read -p "Enter TLS Admin username:" tlsadmin
	# read -s -p "Enter TLS Admin password:" tlsadminpw

	# Create the TLS Server directory
	mkdir -p "$FABRIC_CA_SERVER_HOME" && cd "$FABRIC_CA_SERVER_HOME" || exit 1

	printInfo "createTLSOpsServer - Initializing the server with bootstrap identity ${tlsadmin}"
	
	fabric-ca-server init -b ${tlsadmin}:${tlsadminpw}
	yes | mv msp/keystore/*sk msp/keystore/rootkey.pem

	# Import existing and configured fabric-ca-server-config.yaml file
	CONF_FILE="$FABRIC_CA_CFG_PATH/fca-tlsops-${ORG_NAME}-config.yaml"
	yes | cp "$CONF_FILE" ./fabric-ca-server-config.yaml
	verifyResult $?  "createTLSOpsServer - Failed to cp config"

	##### IMPORTANT!!
	##### If the csr values on the fabric-ca-server-config.yaml 
	##### are changed, then the previous certificates must be 
	##### deleted and start the server to generate new ones.  
	# rm -rf $FABRIC_CA_SERVER_HOME/msp
	# rm $FABRIC_CA_SERVER_HOME/ca-cert.pem
	cd "$FABRIC_HOME" || exit
	createDockerTLSCAOps "${ORG_NAME}"
	export DOCK_COMPOSE_FILE=${DOCKER_HOME}/docker-compose-tlsops-${ORG_NAME}.yaml

	printSuccess "createTLSOpsServer - TLS Operations Server for ${ORG_NAME} Initialized Succesfully"
	sleep 5
}

# When the server is up, enroll the TLS CA Admin to obtain the key and TLS cert to enable communication 
createTLSOpsClient() {
	printInfo "createTLSOpsClient - Creating the TLS Client..."

	# User Input
	setParams "${ORG_NAME}"

	# Create directory for the client
	mkdir -p "$FABRIC_CA_PATH"/"${ORG_NAME}"/fabric-ca-client-"${ORG_NAME}"
	cd "$FABRIC_CA_CLIENT_HOME" || exit
	
	# Copy the binary to its' folder
	cp "$BINPATH"/fabric-ca-client .
	
	# Directory to store the certificates that are issued upon enrolling 
	# the boostrap identity 
	mkdir tlsops-ca
	
	mkdir tlsops-root-cert

	# Copy tls-cert.pem to the client folder 
	cp "$FABRIC_CA_SERVER_HOME"/ca-cert.pem "$FABRIC_CA_CLIENT_HOME"/tlsops-root-cert/tls-ca-cert.pem

	# Enroll the TLS CA admin user to issue keys and certs
	printInfo "createTLSOpsClient - Enrolling the TLS CA Operations Admin: ${tlsadmin}"
	set -x
	fabric-ca-client enroll -u https://${tlsadmin}:${tlsadminpw}@$tlsHost:$tlsOpsPort --csr.hosts $tlsHost --tls.certfiles tlsops-root-cert/tls-ca-cert.pem --enrollment.profile tls --mspdir tlsops-ca/${tlsadmin}/msp 
	res=$?
	set +x
	verifyResult $res "createTLSOpsClient - Failed to enroll identity: ${tlsadmin}"

	mv "$FABRIC_CA_CLIENT_HOME"/tlsops-ca/${tlsadmin}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/tlsops-ca/${tlsadmin}/msp/keystore/key.pem
	cd "$FABRIC_HOME" || exit
	printSuccess "createTLSOpsClient - Operations TLS Client Admin ${tlsadmin} enrolled successfully!"
}

# # Register and Enroll the CA Admin via the TLS CA Admin to issue keys and certs to the TLS Server
# enrollTLSCAOpsAdmin() {
# 	printInfo "Registering the Operations TLS CA Admin..."

# 	# User Input 
# 	setParams "${ORG_NAME}"
# 	# Does not need to be the same as the enrolled name and pw in the TLS Server
	
# 	# Read ..
# 	# Repeat pw.

# 	# Register CA Admin to the TLS CA via the TLS CA Admin
# 	cd "$FABRIC_CA_CLIENT_HOME" || exit
# 	set -x
# 	fabric-ca-client register --id.name ${caadmin} --id.secret ${caadminpw} -u https://"${tlsendpoint}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --mspdir tlsops-ca/${tlsadmin}/msp
# 	res=$?
# 	set +x
# 	verifyResult $res "Failed to register the CA Admin to the TLS Server" 
# 	printSuccess "CA Admin registered succesfully"

# 	# Enroll CA Admin to obtain keys and certificates
# 	printInfo "Enrolling the CA Admin..."
# 	set -x
# 	fabric-ca-client enroll -u https://${caadmin}:${caadminpw}@"${tlsendpoint}" --csr.hosts ${tlsHost} --tls.certfiles tls-root-cert/tls-ca-cert.pem --enrollment.profile tls --mspdir tlsops-ca/${caadmin}/msp 
# 	set +x

# 	# Rename the secret key to key.pem for easier manipulation
# 	mv "$FABRIC_CA_CLIENT_HOME"/tlsops-ca/${caadmin}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/tlsops-ca/${caadmin}/msp/keystore/key.pem
# 	res=$?
# 	cd "$FABRIC_HOME" || exit
# 	verifyResult $res "Failed to enroll the CA Admin to the TLS Server"
# 	printSuccess "CA Admin enrolled succesfully"
# 	sleep 3
# }

createTLSOpsCA() {
	export FABRIC_CA_SERVER_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-tlscaops-server-${ORG_NAME}
	export FABRIC_CA_CLIENT_HOME=$FABRIC_CA_PATH/${ORG_NAME}/fabric-ca-client-${ORG_NAME}

	if [ -z "${ORG_NAME}" ]; then
		printError "createTLSOpsCA - Missing ORG_NAME"
		exit 1
	fi
	
	mkdir -p $FABRIC_CA_PATH

	createTLSOpsServer
	startServer 
	mv ${FABRIC_CA_SERVER_HOME}/msp/keystore/*sk ${FABRIC_CA_SERVER_HOME}/msp/keystore/tlskey.pem

	createTLSOpsClient  
	# enrollTLSCAAdmin  

	printSuccess "createTLSOpsCA - TLS Server-Client for Operations of ${ORG_NAME} created successfully!"

}