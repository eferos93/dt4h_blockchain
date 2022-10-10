#!/bin/bash

node_types="peer client orderer admin"

# Register Peer to TLS and CA Servers
register() {
	# Check for org existence
	if [ -z "${ORG_NAME}" ]; then
		printError "register - No org specified."
		exit 1
	fi

	validate_type "$TYPE"
	if [[ "$status" == false ]]; then 
		printError "register - No TYPE specified."
		exit 1
	fi

	if [ -z "$USERNAME" ]; then
		printError "register - No USERNAME specified"
		exit 1
	fi

	if [ -z "$SECRET" ]; then
		printError "register - No enrollment secret specified." 
		exit 1
	fi

	printInfo "register - Registering ${ORG_NAME} ${TYPE} $USERNAME"

	setParams "${ORG_NAME}"

	# MSP dirs of the TLS/CA Admin
	TLSMSPDIR="$FABRIC_CA_CLIENT_HOME"/tls-ca/tlsadmin/msp
	CAMSPDIR="$FABRIC_CA_CLIENT_HOME"/${ORG_NAME}-ca/rcaadmin/msp
	TLSOPSDIR=$FABRIC_CA_CLIENT_HOME/tlsops-ca/tlsadmin/msp

	# USERNAME=$(ls ${FABRIC_HOME}/organizations/peerOrganizations/${ORG_NAME}.domain.com/peers | wc -l | sed 's/^ *//')	
	USERNAME="$USERNAME"

	# # Check if a config file for the peer exists
	# if [[ "$TYPE" == "peer" || "$TYPE" == "orderer" ]] && [[ ! -f "$FABRIC_HOME"/config/"$USERNAME"-"${ORG_NAME}".yaml ]]; then
	# 	printError "Config for ${USERNAME}-${ORG_NAME} does not exist."
	# 	echo "Please create a configuration file for the peer with name ${USERNAME}-${ORG_NAME}.yaml and add it to the folder: config"
	# 	exit 1
	# fi	

	if [ "$TYPE" == "admin" ]; then
		attrs="--id.attrs hf.Registrar.Roles=* --id.attrs hf.GenCRL=true"
	elif [ "$TYPE" == "peer" ]; then
		attrs="--id.attrs hf.GenCRL=true"
	else
		attrs=""
	fi

	# Register to TLS Server
	set -x
	fabric-ca-client register -M "$TLSMSPDIR" -u https://"$tlsendpoint" --tls.certfiles "$TLS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET"  --caname "$tlscaName" ${attrs}
	res=$?
	set +x 
	# verifyResult "$res" "Registration of peer to TLS Server failed"

	# Register to CA Server
	set -x
	fabric-ca-client register -M "$CAMSPDIR" -u https://"$caendpoint" --tls.certfiles "$TLS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET"  --caname "$caName" ${attrs}
	res=$?
	set +x 
	# verifyResult "$res" "Registration of peer to CA Server failed"

	# Register to TLS Operations Server
	set -x
	fabric-ca-client register -M "$TLSOPSDIR" -u https://"$tlsopsendpoint" --tls.certfiles "$TLSOPS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET" ${attrs}
	res=$?
	set +x 
	# verifyResult "$res" "Registration of peer to TLS Server failed"

	printSuccess "register - ${ORG_NAME} ${USERNAME} registered successfully"
}

# registerPeer

validate_type() {
	status=false
	input=$1
	
	if [[ -z "$input" ]]; then
		return
	fi
	
	for type in $node_types; do
		if [[ "$input" == "$type" ]]; then
			status=true
			return
		fi
	done

}