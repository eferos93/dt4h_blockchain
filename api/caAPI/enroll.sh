#!/bin/bash

# Enroll node to obtain MSP

enroll() {
	printInfo "enroll - Enrolling ${ORG_NAME} ${TYPE}..."

	# Check for org existence
	if [ -z ${ORG_NAME} ]; then
		printError "enroll - No org specified"
		exit 1
	fi

	validate_type "$TYPE"
	if [[ "$status" == false ]]; then 
		printError "enroll - No TYPE specified"
		exit 1
	fi

	if [ -z "$USERNAME" ]; then
		printError "enroll - No username specified"
		exit 1
	fi

	if [ -z "$SECRET" ]; then
		printError "enroll - No enrollment secret specified" 
		exit 1
	fi

	# is_user_root

	NODE_HOME=$FABRIC_HOME/organizations/${typeOfOrg}Organizations/${ORG_NAME}.domain.com/users/"$USERNAME"

	if [[ "$TYPE" == "peer" ]]; then
		# # Check if a config file for the peer exists
		# if [[ ! -f "$FABRIC_HOME"/config/"$USERNAME"-${ORG_NAME}.yaml ]]; then
		# 	printError "Config for ${USERNAME}-${ORG_NAME} does not exist."
		# 	echo "Please create a configuration file for the peer with name ${USERNAME}-${ORG_NAME}.yaml and add it to the folder: config"
		# 	exit 1
		# fi

		NODE_HOME=$FABRIC_HOME/organizations/peerOrganizations/${ORG_NAME}.domain.com/"$TYPE"s/"$USERNAME".${ORG_NAME}.domain.com
	elif [[ "$TYPE" == "orderer" ]]; then
		# # Check if a config file for the orderer exists
		# if [[ ! -f "$FABRIC_HOME"/config/"$USERNAME"-${ORG_NAME}.yaml ]]; then
		# 	printError "Config for ${USERNAME}-${ORG_NAME} does not exist."
		# 	echo "Please create a configuration file for the orderer with name ${USERNAME}-${ORG_NAME}.yaml and add it to the folder: config"
		# 	exit 1
		# fi

		NODE_HOME=$FABRIC_HOME/organizations/ordererOrganizations/${ORG_NAME}.domain.com/"$TYPE"s/"$USERNAME".${ORG_NAME}.domain.com
	
	fi
	
	# Set MSP directory to store the files
	CAMSPDIR=$NODE_HOME/msp
	TLSMSPDIR=$NODE_HOME/tls
	TLSOPSDIR=$NODE_HOME/tlsops
	OLDMSPSDIR=$NODE_HOME/oldmsps

	# Create the node's directory
	[ ! -d "$NODE_HOME" ] &&  mkdir -p "$NODE_HOME"

	# Create folder to put old MSP files
	[ -d "$CAMSPDIR" ] && [ ! -d "$OLDMSPSDIR" ] && mkdir -p "$OLDMSPSDIR"
	[ -d "$OLDMSPSDIR" ] && msp_no="$(ls "$OLDMSPSDIR" | wc -l)" && mkdir -p "$OLDMSPSDIR"/$msp_no

	[ -z $CA_TYPE ] && printInfo "Enrolling to all CAs" || printInfo "Enrolling to ${CA_TYPE^^} CA"

	##### TLS #####
	if [ -z "$CA_TYPE" ] || [ "$CA_TYPE" == 'tls' ]; then
		# Move the old msp to oldmsp folder
		[ -d "$TLSMSPDIR" ] && mv "$TLSMSPDIR" "$OLDMSPSDIR"/$msp_no
		set -x
		fabric-ca-client enroll -d -M "$TLSMSPDIR" -u https://"$USERNAME":"$SECRET"@"${TLS_ENDPOINT}" --enrollment.profile tls --tls.certfiles "$TLS_ROOTCERT_PATH" --csr.hosts localhost,"$USERNAME".${ORG_NAME}.domain.com
		res=$?
		set +x
		verifyResult "$res" "enroll - Failed to enroll $TYPE $USERNAME to TLS Server"
		mv "$TLSMSPDIR"/keystore/* "$TLSMSPDIR"/keystore/key.pem
		mv "$TLSMSPDIR"/tlscacerts/* "$TLSMSPDIR"/tlscacerts/ca.crt
	fi

	##### CA #####
	if [ -z "$CA_TYPE" ] || [ "$CA_TYPE" == 'ca' ]; then
		[ -d "$CAMSPDIR" ] && mv "$CAMSPDIR" "$OLDMSPSDIR"/$msp_no
		set -x 
		fabric-ca-client enroll -d -M "$CAMSPDIR" -u https://"$USERNAME":"$SECRET"@"${CA_ENDPOINT}" --tls.certfiles "$TLS_ROOTCERT_PATH" --csr.hosts localhost,"$USERNAME".${ORG_NAME}.domain.com
		res=$?
		set +x
		verifyResult "$res" "enroll - Failed to enroll $TYPE $USERNAME to CA Server"
		mv "$CAMSPDIR"/keystore/* "$CAMSPDIR"/keystore/key.pem
		mv "$CAMSPDIR"/cacerts/* "$CAMSPDIR"/cacerts/cacert.pem
		cp -R "$TLSMSPDIR"/tlscacerts "$CAMSPDIR"/
	fi

	#### TLS OPS #####
	if [ -z "$CA_TYPE" ] || [ "$CA_TYPE" == 'tlsops' ]; then
		[ -d "$TLSOPSDIR" ] && mv "$TLSOPSDIR" "$OLDMSPSDIR"/$msp_no
		set -x 
		fabric-ca-client enroll -M "$TLSOPSDIR" -u https://"$USERNAME":"$SECRET"@"${TLSOPS_ENDPOINT}" --enrollment.profile tls --tls.certfiles "$TLSOPS_ROOTCERT_PATH" --csr.hosts localhost,"$USERNAME".${ORG_NAME}.domain.com
		res=$?
		set +x
		verifyResult "$res" "enroll - Failed to enroll $TYPE $USERNAME to TLS CA Operations Server"
		mv "$TLSOPSDIR"/keystore/* "$TLSOPSDIR"/keystore/key.pem
		mv "$TLSOPSDIR"/tlscacerts/* "$TLSOPSDIR"/tlscacerts/ca.crt
	fi

	# Create config.yaml on MSP folder for NODE OUs
	createNodeOUs "$CAMSPDIR"
	printSuccess "enroll - ${ORG_NAME} $TYPE: $USERNAME enrolled succesfully"
}

# enroll

is_user_root () {
	if [[ $EUID != 0 ]]; then
    	echo "Please run as root"
    	exit 1
	fi
}