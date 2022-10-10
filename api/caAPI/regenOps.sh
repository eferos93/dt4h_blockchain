#!/bin/bash

# Register Users-ORG admin to TLS and CA Servers
registerClientOps() {
	if [ -z "$ORG_NAME" ]; then
		printError "registerClientOps - No org specified."
		exit 1
	fi

	printInfo "registerClientOps - Registering the Operations client..."

	setParams "$ORG_NAME"

	# MSP files of the TLS/CA Admin
	TLSOPSDIR=$FABRIC_CA_CLIENT_HOME/tlsops-ca/tlsadmin/msp

	if [ "$type" == "admin" ]; then
		attrs="--id.attrs hf.Registrar.Roles=client"
	else
		attrs=" "
	fi
	
	# Register to TLS Operations Server
	set -x
	fabric-ca-client register -M "$TLSOPSDIR" -u https://"$tlsopsendpoint" --tls.certfiles "$TLSOPS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "$USERNAME" --id.secret "$SECRET" ${attrs}
	res=$?
	set +x 
	# verifyResult "$res" "Registration of peer to TLS Server failed"


	printSuccess "registerClientOps - ${ORG_NAME} ${type} $USERNAME registered succesfully"

}

# Enroll user
enrollClientOps() {
	# Check for ORG_NAME existence
	if [ -z "$ORG_NAME" ]; then
		printError "enrollClientOps - No ORG_NAME specified"
		exit 1
	fi

	validate_type "$TYPE"
	if [[ "$status" == false ]]; then 
		printError "enrollClientOps - No TYPE specified"
		exit 1
	fi

	if [ -z "$USERNAME" ]; then
		printError "enrollClientOps - No username specified"
		exit 1
	fi

	if [ -z "$SECRET" ]; then
		printError "enrollClientOps - No enrollment secret specified" 
		exit 1
	fi

	# is_user_root

	printInfo "enrollClientOps - Enrolling ${ORG_NAME} ${TYPE} $USERNAME..."

	setParams "$ORG_NAME"
	
	NODE_HOME=$FABRIC_HOME/organizations/"$typeOfOrg"Organizations/${ORG_NAME}.domain.com/users/"$USERNAME"
	TLSOPSDIR=$NODE_HOME/tlsops

	# TLS Operations Certs
	set -x 
	fabric-ca-client enroll -M "$TLSOPSDIR" -u https://"$USERNAME":"$SECRET"@"$tlsopsendpoint" --enrollment.profile tls --tls.certfiles "$TLSOPS_ROOTCERT_PATH" --csr.hosts localhost,"$USERNAME"."$ORG_NAME".domain.com
	res=$?
	set +x
	verifyResult "$res" "enrollClientOps - Failed to enroll $TYPE to TLS CA Operations Server"
	mv "$TLSOPSDIR"/keystore/* "$TLSOPSDIR"/keystore/key.pem
	mv "$TLSOPSDIR"/tlscacerts/* "$TLSOPSDIR"/tlscacerts/ca.crt

	printSuccess "enrollClientOps - ${ORG_NAME} $TYPE $USERNAME enrolled succesfully"
}

regenOps() {
	validate_type "$TYPE"

	registerClientOps 
	enrollClientOps 
}