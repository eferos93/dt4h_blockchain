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

	# MSP dirs of the TLS/CA Admin
	TLSMSPDIR="$FABRIC_CA_CLIENT_HOME"/tls-ca/${TLS_ADMIN}/msp
	TLSOPSDIR=$FABRIC_CA_CLIENT_HOME/tlsops-ca/${TLS_ADMIN}/msp

	if [ "$TYPE" == "admin" ]; then
		attrs="--id.attrs hf.Registrar.Roles=*,hf.GenCRL=true"
	elif [ "$TYPE" == "peer" ]; then
		attrs="--id.attrs hf.GenCRL=true"
	else
		attrs=""
	fi

	# Register to CA Server
	set -x
	fabric-ca-client register -M "$CAMSPDIR" -u https://"${CA_ENDPOINT}" --tls.certfiles "$TLS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET"  --caname "$CA_NAME" ${attrs}
	res=$?
	set +x 
	# verifyResult "$res" "Registration of peer to CA Server failed"

	if [ -z $USERS ]; then
		# Register to TLS Server
		set -x
		fabric-ca-client register -M "$TLSMSPDIR" -u https://"${TLS_ENDPOINT}" --tls.certfiles "$TLS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET"  --caname "${TLS_CANAME}" ${attrs}
		res=$?
		set +x 
		# verifyResult "$res" "Registration of peer to TLS Server failed"

		# Register to TLS Operations Server
		set -x
		fabric-ca-client register -M "$TLSOPSDIR" -u https://"${TLSOPS_ENDPOINT}" --tls.certfiles "$TLSOPS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET" ${attrs}
		res=$?
		set +x 
		# verifyResult "$res" "Registration of peer to TLS Server failed"

		printSuccess "register - ${ORG_NAME} ${USERNAME} registered successfully"
	fi
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