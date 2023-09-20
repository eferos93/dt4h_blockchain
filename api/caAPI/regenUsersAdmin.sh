#!/bin/bash
#
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# Registers the User Organization's admin to TLS and CA servers.
# Validates the input, prepares necessary attributes, and performs the registration.
registerUsersAdmin() {
	method='registerUsersAdmin'
	
	# Validate organization name
	if [ -z "${ORG_NAME}" ]; then
		printError "${method} - No org specified."
		exit 1
	fi

	printInfo "${method} - Registering the ${ORG_NAME}-users ${TYPE}..."

	# Directory paths for TLS and CA Admin's MSP files
	TLSMSPDIR="$FABRIC_CA_CLIENT_HOME"/tls-ca/${TLS_ADMIN}/msp
	CAMSPDIR="$FABRIC_CA_CLIENT_HOME"/${ORG_NAME}-users-ca/${USERSCA_ADMIN}/msp
	
	# Determine attributes based on user type
	if [ "$TYPE" == "admin" ]; then
		attrs="--id.attrs hf.Registrar.Roles=client,hf.Revoker=true"
	else
		attrs=" "
	fi

	# Register with CA server
	set -x
	fabric-ca-client register -M "$CAMSPDIR" -u https://"${CA_ENDPOINT}" --tls.certfiles "$TLS_ROOTCERT_PATH" --id.type "$TYPE" --id.name "${ORG_USERS_ADMIN}" --id.secret "${ORG_USERS_ADMIN_PW}"  --caname "$caName"-users ${attrs}
	res=$?
	set +x
	printSuccess "${method} - ${ORG_NAME} ${TYPE} ${ORG_USERS_ADMIN} registered successfully"
}

# Enrolls the User Organization's admin.
# Validates the organization name and performs the enrollment.
enrollUsersAdmin() {
	
	# Validate organization name
	if [ -z "${ORG_NAME}" ]; then
		printError "enrollUsersAdmin - No org specified."
		exit 1
	fi

	printInfo "enrollUsersAdmin - Enrolling ${ORG_NAME}-users ${TYPE}..."

	# Directory paths and setup for user's MSP
	USERS_HOME=${FABRIC_HOME}/organizations/peerOrganizations/${ORG_NAME}.domain.com/${ORG_NAME}-users/
	USER_HOME=${USERS_HOME}/users/${ORG_USERS_ADMIN}/
	mkdir -p ${USER_HOME}
	CAMSPDIR=${USER_HOME}/msp

	# Enroll with CA server
	set -x 
	fabric-ca-client enroll -M "$CAMSPDIR" -u https://${ORG_USERS_ADMIN}:${ORG_USERS_ADMIN_PW}@"${CA_ENDPOINT}" --caname "${CA_NAME}"-users --tls.certfiles "$TLS_ROOTCERT_PATH" --csr.hosts localhost,"${ORG_NAME}".domain.com
	res=$?
	set +x
	verifyResult "$res" "enrollUsersAdmin - Failed to enroll ${TYPE} to CA Server"

	# Arrange the keys and certificates in proper directories
	mv "$CAMSPDIR"/keystore/* "$CAMSPDIR"/keystore/key.pem
	mv "$CAMSPDIR"/cacerts/* "$CAMSPDIR"/cacerts/cacert.pem

	# Uncomment the below if you need to copy CA certs from a specific path
	# cp "$FABRIC_CA_PATH"/${ORG_NAME}/fabric-ca-client-${ORG_NAME}/${ORG_NAME}-users-ca/${USERS_CAADMIN}/msp/cacerts/*  "$CAMSPDIR"/cacerts/cacert-users.pem

	# Create NodeOUs and set up the user's MSP
	set -x
	createNodeOUs "$CAMSPDIR"
	USERSMSPDIR=$USERS_HOME/../usersmsp
	mkdir -p "$USERSMSPDIR"/cacerts
	cp -r "$CAMSPDIR"/cacerts/cacert.pem "$USERSMSPDIR"/cacerts/cacert.pem
	cp "$CAMSPDIR"/config.yaml "$USERSMSPDIR"
	createNodeOUs "$USERSMSPDIR"
	set +x

	printSuccess "enrollUsersAdmin - ${ORG_NAME} ${TYPE} ${ORG_USERS_ADMIN} enrolled successfully"
}

# Wrapper function to first register and then enroll the User Organization's admin.
createUsersOrgAdmin() {
	validate_type "$TYPE"
	registerUsersAdmin 
	enrollUsersAdmin 
}