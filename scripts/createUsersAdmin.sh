#!/bin/bash

# Register user
registerUsersAdmin() {
	org=$1

	if [ -z "$org" ]; then
		printError "registerUsersAdmin - No org specified."
		exit 1
	fi

	printInfo "registerUsersAdmin - Registering the ${org}-users ${type}..."

	setParams "$org"

	# MSP files of the TLS/CA Admin
	TLSMSPDIR="$FABRIC_CA_CLIENT_HOME"/tls-ca/${tlsadmin}/msp
	CAMSPDIR="$FABRIC_CA_CLIENT_HOME"/${org}-users-ca/${userscaadmin}/msp
	
	if [ "$type" == "admin" ]; then
		attrs="--id.attrs hf.Registrar.Roles=client --id.attrs hf.GenCRL=true --id.attrs hf.Revoker=true"
	else
		attrs=" "
	fi
	
	set -x
	fabric-ca-client register -M "$CAMSPDIR" -u https://"$caendpoint" --tls.certfiles "$TLS_ROOTCERT_PATH" --id.type "$type" --id.name "$user" --id.secret "$userpw"  --caname "$caName"-users ${attrs}
	res=$?
	set +x

	printSuccess "registerUsersAdmin - ${org} ${type} registered successfully"

}

# Enroll user
enrollUsersAdmin() {
	org=$1	

	if [ -z "$org" ]; then
		printError "enrollUsersAdmin - No org specified."
		exit 1
	fi

	printInfo "enrollUsersAdmin - Enrolling ${org}-users ${type}..."

	setParams "$org"

	USERS_HOME=${FABRIC_HOME}/organizations/peerOrganizations/${org}.domain.com/${org}-users/
	USER_HOME=$USERS_HOME/users/${user}/
	mkdir -p ${USER_HOME}
	CAMSPDIR=$USER_HOME/msp

	# Enroll to CA Server
	set -x 
	fabric-ca-client enroll -M "$CAMSPDIR" -u https://$user:$userpw@"$caendpoint" --caname "$caName"-users --tls.certfiles "$TLS_ROOTCERT_PATH" --csr.hosts localhost,"$org".domain.com
	res=$?
	set +x
	verifyResult "$res" "enrollUsersAdmin - Failed to enroll ${type} to CA Server"

	mv "$CAMSPDIR"/keystore/* "$CAMSPDIR"/keystore/key.pem
	mv "$CAMSPDIR"/cacerts/* "$CAMSPDIR"/cacerts/cacert.pem

	# cp "$FABRIC_CA_PATH"/${org}/fabric-ca-client-${org}/${org}-users-ca/${userscaadmin}/msp/cacerts/*  "$CAMSPDIR"/cacerts/cacert-users.pem

	createNodeOUs "$CAMSPDIR"

	USERSMSPDIR=$USERS_HOME/../usersmsp
	mkdir -p "$USERSMSPDIR"/cacerts
	cp -r "$CAMSPDIR"/cacerts/cacert.pem "$USERSMSPDIR"/cacerts/cacert.pem
	cp -r "$CAMSPDIR"/config.yaml "$USERSMSPDIR"/

	printSuccess "enrollUsersAdmin - ${org} ${type} enrolled successfully"
}

createOrgUsersAdmin() {
	org=$1
	type=$2

	if [ "$type" != "admin" ] && [ "$type" != "client" ]; then
		# printError "Wrong type of node"
		return
	fi

	registerUsersAdmin "$org"
	enrollUsersAdmin "$org"
}
