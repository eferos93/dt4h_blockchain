#!/bin/bash

# Reenroll node to obtain MSP

reenroll() {
	printInfo "reenroll - Reenrolling ${ORG_NAME} ${TYPE}..."

	# Check for org existence
	if [ -z "${ORG_NAME}" ]; then
		printError "reenroll - No org specified"
		exit 1
	fi

	validate_type "$TYPE"
	if [[ "$status" == false ]]; then 
		printError "reenroll - No TYPE specified"
		exit 1
	fi

	if [ -z "$USERNAME" ]; then
		printError "reenroll - No username specified"
		exit 1
	fi

	# if [ -z "$SECRET" ]; then
	# 	printError "reenroll - No enrollment secret specified" 
	# 	exit 1
	# fi

	is_user_root

	setParams "${ORG_NAME}"

	NODE_HOME=$FABRIC_HOME/organizations/${typeOfOrg}Organizations/${ORG_NAME}.domain.com/users/"$USERNAME"

	if [[ "$TYPE" == "peer" ]]; then
		# # Check if a config file for the peer exists
		# if [[ ! -f "$FABRIC_HOME"/config/"$USERNAME"-"${ORG_NAME}".yaml ]]; then
		# 	printError "Config for ${USERNAME}-${ORG_NAME} does not exist."
		# 	echo "Please create a configuration file for the peer with name ${USERNAME}-${ORG_NAME}.yaml and add it to the folder: config"
		# 	exit 1
		# fi

		NODE_HOME=$FABRIC_HOME/organizations/peerOrganizations/${ORG_NAME}.domain.com/"$TYPE"s/"$USERNAME".${ORG_NAME}.domain.com
	elif [[ "$TYPE" == "orderer" ]]; then
		# # Check if a config file for the orderer exists
		# if [[ ! -f "$FABRIC_HOME"/config/"$USERNAME"-"${ORG_NAME}".yaml ]]; then
		# 	printError "Config for ${USERNAME}-${ORG_NAME} does not exist."
		# 	echo "Please create a configuration file for the orderer with name ${USERNAME}-${ORG_NAME}.yaml and add it to the folder: config"
		# 	exit 1
		# fi

		NODE_HOME=$FABRIC_HOME/organizations/ordererOrganizations/${ORG_NAME}.domain.com/"$TYPE"s/"$USERNAME".${ORG_NAME}.domain.com
	fi

	# Set MSP directory to store the files
	CAMSPDIR=$NODE_HOME/msp
	TLSMSPDIR=$NODE_HOME/tls
	OLDMSPSDIR=$NODE_HOME/oldmsps

	# Create the node's directory
	[ ! -d "$NODE_HOME" ] &&  mkdir -p "$NODE_HOME"

	# Create folder to put old MSP files
	[ -d "$CAMSPDIR" ] && [ ! -d "$OLDMSPSDIR" ] && mkdir -p "$OLDMSPSDIR"
	[ -d "$OLDMSPSDIR" ] && msp_no="$(ls "$OLDMSPSDIR" | wc -l)" && mkdir -p "$OLDMSPSDIR"/$msp_no

	[ -z $CA_TYPE ] && printInfo "Reenrolling to all CAs" || printInfo "Reenrolling to ${CA_TYPE^^} CA"
	
	##### TLS #####
	if [ -z "$CA_TYPE" ] || [ "$CA_TYPE" == 'tls' ]; then
		# Move the old msp to oldmsp folder
		[ -d "$TLSMSPDIR" ] && cp -r "$TLSMSPDIR" "$OLDMSPSDIR"/$msp_no
		# exit
		set -x
		fabric-ca-client reenroll -d ${REUSE_KEY} -M "$TLSMSPDIR" -u https://"$tlsendpoint" --enrollment.profile tls --tls.certfiles "$TLS_ROOTCERT_PATH" --csr.hosts localhost,"$USERNAME"."${ORG_NAME}".domain.com,tlsca_"${ORG_NAME}"
		res=$?
		set +x
		verifyResult "$res" "reenroll - Failed to enroll $TYPE $USERNAME to TLS Server"

		# Remove previous key/cert
		if [ -z ${REUSE_KEY} ]; then
			rm "$TLSMSPDIR"/keystore/key.pem
			mv "$TLSMSPDIR"/keystore/* "$TLSMSPDIR"/keystore/key.pem
		fi
		
		rm "$TLSMSPDIR"/tlscacerts/ca.crt
		mv "$TLSMSPDIR"/tlscacerts/* "$TLSMSPDIR"/tlscacerts/ca.crt
	fi

	##### CA #####
	if [ -z "$CA_TYPE" ] || [ "$CA_TYPE" == 'ca' ]; then
		[ -d "$CAMSPDIR" ] && cp -r "$CAMSPDIR" "$OLDMSPSDIR"/$msp_no
		set -x 
		fabric-ca-client reenroll -d ${REUSE_KEY}  -M "$CAMSPDIR" -u https://"$caendpoint" --tls.certfiles "$TLS_ROOTCERT_PATH" --csr.hosts localhost,"$USERNAME"."${ORG_NAME}".domain.com,ca_"${ORG_NAME}"
		res=$?
		set +x
		verifyResult "$res" "reenroll - Failed to enroll $TYPE $USERNAME to CA Server"
		
		# Remove previous key/cert
		if [ -z ${REUSE_KEY} ]; then
			rm "$CAMSPDIR"/keystore/key.pem
			rm "$CAMSPDIR"/cacerts/cacert.pem
			mv "$CAMSPDIR"/keystore/* "$CAMSPDIR"/keystore/key.pem
			mv "$CAMSPDIR"/cacerts/* "$CAMSPDIR"/cacerts/cacert.pem
			cp -R "$TLSMSPDIR"/tlscacerts "$CAMSPDIR"/
		fi

	fi

	# Create config.yaml on MSP folder for NODE OUs
	createNodeOUs "$CAMSPDIR"
	printSuccess "reenroll - ${ORG_NAME} $TYPE: $USERNAME reenrolled successfully"
}
