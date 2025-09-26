#!/bin/bash

# Register a client to Operations TLS and CA servers.
# Validates the input, prepares necessary attributes and performs the registration.
registerClientOps() {
	# Validate the organization name
	if [ -z "$ORG_NAME" ]; then
		printError "registerClientOps - No org specified."
		exit 1
	fi

	printInfo "registerClientOps - Registering the Operations client..."

	# Set parameters for the organization
	setParams "$ORG_NAME"

	# Directory path for MSP files of the TLS/CA Admin
	TLSOPSDIR=$FABRIC_CA_CLIENT_HOME/tlsops-ca/tlsadmin/msp

	# Set registration attributes based on client type
	if [ "$type" == "admin" ]; then
		attrs="--id.attrs hf.Registrar.Roles=client"
	else
		attrs=""
	fi
	
	# Execute the registration command for TLS Operations Server
	set -x
	fabric-ca-client register -M "$TLSOPSDIR" -u https://"${TLSOPS_ENDPOINT}" --tls.certfiles "$TLSOPS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET" ${attrs}
	res=$?
	set +x 
	# Uncomment below to check the registration result
	# verifyResult "$res" "Registration of peer to TLS Server failed"

	printSuccess "registerClientOps - ${ORG_NAME} ${type} $USERNAME registered successfully"
}

# Enroll a client to receive its certificates.
# Validates the input and performs the enrollment.
enrollClientOps() {
	# Validate the organization name
	if [ -z "$ORG_NAME" ]; then
		printError "enrollClientOps - No ORG_NAME specified"
		exit 1
	fi

	# Validate the client type
	validate_type "$TYPE"
	if [[ "$status" == false ]]; then 
		printError "enrollClientOps - No TYPE specified"
		exit 1
	fi

	# Validate the username and enrollment secret
	if [ -z "$USERNAME" ]; then
		printError "enrollClientOps - No username specified"
		exit 1
	fi
	if [ -z "$SECRET" ]; then
		printError "enrollClientOps - No enrollment secret specified" 
		exit 1
	fi

	printInfo "enrollClientOps - Enrolling ${ORG_NAME} ${TYPE} $USERNAME..."

	# Directory paths for the node and TLS operations
	NODE_HOME=$FABRIC_HOME/organizations/"$typeOfOrg"Organizations/${ORG_NAME}.dt4h.com/users/"$USERNAME"
	TLSOPSDIR=$NODE_HOME/tlsops

	# Execute the enrollment command for TLS Operations Certificates
	set -x 
	fabric-ca-client enroll -M "${TLSOPSDIR}" -u https://"$USERNAME":"$SECRET"@"${TLSOPS_ENDPOINT}" --enrollment.profile tls --tls.certfiles "$TLSOPS_ROOTCERT_PATH" --csr.hosts localhost,"$USERNAME"."$ORG_NAME".dt4h.com
	res=$?
	set +x
	verifyResult "$res" "enrollClientOps - Failed to enroll $TYPE to TLS CA Operations Server"

	# Arrange the keys and certificates in proper directories
	mv "$TLSOPSDIR"/keystore/* "$TLSOPSDIR"/keystore/key.pem
	mv "$TLSOPSDIR"/tlscacerts/* "$TLSOPSDIR"/tlscacerts/ca.crt

	printSuccess "enrollClientOps - ${ORG_NAME} $TYPE $USERNAME enrolled successfully"
}

# Register enroll operations for a client.
# Wrapper function to first register and then enroll a client.
regenOps() {
	validate_type "$TYPE"
	registerClientOps 
	enrollClientOps 
}
