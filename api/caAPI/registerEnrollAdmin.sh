#!/bin/bash

# Register Org admin to TLS and CA Servers
# Commands executed by the admins of TLS CA and CA respectively
registerOrgAdmin() {

	if [ -z "${ORG_NAME}" ]; then
		printError "enrollOrgAdmin - No organization specified"
		exit 1
	fi

	if [ "${TYPE}" != "peer" ] &&  [ "${TYPE}" != "orderer" ]; then
		printError "enrollOrgAdmin - Not supported type of org: ${TYPE}"
		exit 1
	fi

	printInfo "registerOrgAdmin - Register the Org Admin $admin of ${ORG_NAME}"

	mkdir -p organizations/"${TYPE}"Organizations/${ORG_NAME}.domain.com

	# read -p "Enter admin username:" admin
	# read -s -p "Enter admin password:" adminpw

	set -x
	fabric-ca-client register --mspdir ${FABRIC_CA_CLIENT_HOME}/tls-ca/${TLS_ADMIN}/msp -u https://${TLS_ENDPOINT} --id.name $admin --id.secret $adminpw --id.type admin --caname tlsca-${ORG_NAME} --tls.certfiles $TLS_ROOTCERT_PATH  
	res=$?
	set +x
	verifyResult $res "registerOrgAdmin - Failed to register Org Admin $admin to TLS Server"
	
	set -x
	fabric-ca-client register --mspdir ${FABRIC_CA_CLIENT_HOME}/${ORG_NAME}-ca/${CA_ADMIN}/msp -u https://${CA_ENDPOINT} --id.name $admin --id.secret $adminpw --id.type admin --caname ca-${ORG_NAME} --tls.certfiles $TLS_ROOTCERT_PATH  
	res=$?
	set +x
	verifyResult $res "registerOrgAdmin - Failed to register Org Admin $admin to CA Server"

	printSuccess "registerOrgAdmin - Org Admin $admin registered to TLS and CA Sever succesfully"
}

# Enroll the Org admin to acquire the Org's MSP
enrollOrgAdmin() {

	if [ -z "${ORG_NAME}" ]; then
		printError "enrollOrgAdmin - No organization specified"
		exit 1
	fi

	if [ "${TYPE}" != "peer" ] &&  [ "${TYPE}" != "orderer" ]; then
		printError "enrollOrgAdmin - Not supported type of org: ${TYPE}"
		exit 1
	fi

	printInfo "enrollOrgAdmin - Enroll the Admin of ${ORG_NAME}"

	# Set MSP/TLS Paths
	ORG_HOME=${FABRIC_HOME}/organizations/"${TYPE}"Organizations/${ORG_NAME}.domain.com
	CAMSPDIR=${ORG_HOME}/msp
	TLSMSPDIR=${ORG_HOME}/tls
	OLDMSPSDIR=${ORG_HOME}/oldmsps
	MSP_CONFIG=${ORG_HOME}/mspConfig

	[ ! -d "$ORG_HOME" ] && mkdir -p "$ORG_HOME"

	# Create folder to put old MSP files
	[ -d "$CAMSPDIR" ] && [ ! -d "$OLDMSPSDIR" ] && mkdir -p "$OLDMSPSDIR"
	[ -d "$OLDMSPSDIR" ] && msp_no="$(ls "$OLDMSPSDIR" | wc -l)" && mkdir -p "$OLDMSPSDIR"/$msp_no

	# Generate new MSPs
	[ -z $CA_TYPE ] && printInfo "Enrolling to all CAs" || printInfo "Enrolling to ${CA_TYPE^^} CA"

	# Enroll to TLS CA
	if [ -z "$CA_TYPE" ] || [ "$CA_TYPE" == 'tls' ]; then
		# Move the old msp to oldmsp folder
		[ -d "${TLSMSPDIR}" ] && mv "${TLSMSPDIR}" "$OLDMSPSDIR"/$msp_no
		set -x
		fabric-ca-client enroll --caname ${TLS_CANAME} --mspdir ${TLSMSPDIR} -u https://$admin:$adminpw@${TLS_ENDPOINT} --tls.certfiles $TLS_ROOTCERT_PATH --enrollment.profile tls
		res=$?
		set +x
		verifyResult $res "enrollOrgAdmin - Failed to enroll ${ORG_NAME} Org Admin to TLS Server"
		mv "${TLSMSPDIR}"/keystore/* "${TLSMSPDIR}"/keystore/key.pem
		mv "${TLSMSPDIR}"/tlscacerts/* "${TLSMSPDIR}"/tlscacerts/cacert.pem
	fi

	# Enroll to CA
	if [ -z "$CA_TYPE" ] || [ "$CA_TYPE" == 'ca' ]; then
		[ -d "$CAMSPDIR" ] && mv "$CAMSPDIR" "$OLDMSPSDIR"/$msp_no
		set -x
		fabric-ca-client enroll --caname ${CA_NAME} --mspdir ${CAMSPDIR} -u https://$admin:$adminpw@${CA_ENDPOINT} --tls.certfiles $TLS_ROOTCERT_PATH 
		res=$?
		set +x
		verifyResult $res "enrollOrgAdmin - Failed to enroll ${ORG_NAME} Org Admin to CA Server"
		mv "${CAMSPDIR}"/keystore/* "${CAMSPDIR}"/keystore/key.pem
		mv "${CAMSPDIR}"/cacerts/*  "${CAMSPDIR}"/cacerts/cacert.pem
	fi

	# IMPORTANT! The organization's MSP MUST include the TLS root cert file
	# to be included in the channel configuration, else the TLS connections 
	# will fail.
	[ -d "${CAMSPDIR}"/tlscacerts ] && rm -rf "${CAMSPDIR}"/tlscacerts
	mkdir "${CAMSPDIR}"/tlscacerts && cp "${TLSMSPDIR}"/tlscacerts/cacert.pem "${CAMSPDIR}"/tlscacerts/ca.crt 
	
	res=$?
	verifyResult "$res" "enrollOrgAdmin - Failed to copy TLS Root-Cert to ${ORG_NAME} MSP"

	createNodeOUs "${CAMSPDIR}"

	# Create an MSP folder to import to System Config, which should not include private key
	[ ! -d ${MSP_CONFIG} ] && mkdir ${MSP_CONFIG}
	cp -r "$CAMSPDIR"/. ${MSP_CONFIG}
	rm -r ${MSP_CONFIG}/keystore
	rm -r ${MSP_CONFIG}/signcerts

	printSuccess "enrollOrgAdmin - Org admin enrolled to TLS and CA Server succesfully"
}

