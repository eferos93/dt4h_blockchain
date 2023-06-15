#!/bin/bash

# Register Users-ORG admin to TLS and CA Servers
registerUsersAdmin() {
	if [ -z "${ORG_NAME}" ]; then
		printError "registerUsersAdmin - No org specified."
		exit 1
	fi

	printInfo "registerUsersAdmin - Registering the ${ORG_NAME}-users ${type}..."

	# MSP files of the TLS/CA Admin
	TLSMSPDIR="$FABRIC_CA_CLIENT_HOME"/tls-ca/${tlsadmin}/msp
	CAMSPDIR="$FABRIC_CA_CLIENT_HOME"/${ORG_NAME}-users-ca/${userscaadmin}/msp
	
	if [ "$type" == "admin" ]; then
		attrs="--id.attrs hf.Registrar.Roles=client --id.attrs hf.Revoker=true"
	else
		attrs=" "
	fi
	
	set -x
	fabric-ca-client register -M "$CAMSPDIR" -u https://"$caendpoint" --tls.certfiles "$TLS_ROOTCERT_PATH" --id.type "$type" --id.name "$user" --id.secret "$userpw"  --caname "$caName"-users ${attrs}
	res=$?
	set +x

	printSuccess "registerUsersAdmin - ${ORG_NAME} ${type} ${user} registered successfully"

}

# Enroll user
enrollUsersAdmin() {
	if [ -z "${ORG_NAME}" ]; then
		printError "enrollUsersAdmin - No org specified."
		exit 1
	fi

	printInfo "enrollUsersAdmin - Enrolling ${ORG_NAME}-users ${type}..."

	USERS_HOME=${FABRIC_HOME}/organizations/peerOrganizations/${ORG_NAME}.domain.com/${ORG_NAME}-users/
	USER_HOME=$USERS_HOME/users/${user}/
	mkdir -p ${USER_HOME}
	CAMSPDIR=$USER_HOME/msp

	# Enroll to CA Server
	set -x 
	fabric-ca-client enroll -M "$CAMSPDIR" -u https://$user:$userpw@"$caendpoint" --caname "$caName"-users --tls.certfiles "$TLS_ROOTCERT_PATH" --csr.hosts localhost,"${ORG_NAME}".domain.com
	res=$?
	set +x
	verifyResult "$res" "enrollUsersAdmin - Failed to enroll ${type} to CA Server"

	mv "$CAMSPDIR"/keystore/* "$CAMSPDIR"/keystore/key.pem
	mv "$CAMSPDIR"/cacerts/* "$CAMSPDIR"/cacerts/cacert.pem

	# cp "$FABRIC_CA_PATH"/${ORG_NAME}/fabric-ca-client-${ORG_NAME}/${ORG_NAME}-users-ca/${userscaadmin}/msp/cacerts/*  "$CAMSPDIR"/cacerts/cacert-users.pem

	createNodeOUs "${ORG_NAME}" "$CAMSPDIR"

	USERSMSPDIR=$USERS_HOME/../usersmsp
	mkdir -p "$USERSMSPDIR"/cacerts
	cp -r "$CAMSPDIR"/cacerts/cacert.pem "$USERSMSPDIR"/cacerts/cacert.pem
	cp -r "$CAMSPDIR"/config.yaml "$USERSMSPDIR"/

	printSuccess "enrollUsersAdmin - ${ORG_NAME} ${type} ${user} enrolled succesfully"
}

createUsersOrgAdmin() {
	validate_type "$TYPE"
	
	registerUsersAdmin 
	enrollUsersAdmin 
}