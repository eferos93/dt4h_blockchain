#!/bin/bash


# Function: registerOrgAdmin
# Description: Register the organization's admin with the TLS and CA servers.
# The registration is executed by the TLS CA and CA admins.
registerOrgAdmin() {
    # Check if the ORG_NAME variable is set
    if [ -z "${ORG_NAME}" ]; then
        printError "enrollOrgAdmin - No organization specified"
        exit 1
    fi

    # Ensure the type is either 'peer' or 'orderer'
    if [ "${TYPE}" != "peer" ] &&  [ "${TYPE}" != "orderer" ]; then
        printError "enrollOrgAdmin - Not supported type of org: ${TYPE}"
        exit 1
    fi

    # Inform about the registration initiation
    printInfo "registerOrgAdmin - Register the Org Admin $admin of ${ORG_NAME}"

    # Create necessary directories
    mkdir -p organizations/"${TYPE}"Organizations/${ORG_NAME}.dt4h.com

    # Register Org admin with the TLS server
    set -x
    fabric-ca-client register --mspdir ${FABRIC_CA_CLIENT_HOME}/tls-ca/${TLS_ADMIN}/msp -u https://${TLS_ENDPOINT} --id.name $admin --id.secret $adminpw --id.type admin --caname tlsca-${ORG_NAME} --tls.certfiles $TLS_ROOTCERT_PATH  
    res=$?
    set +x
    verifyResult $res "registerOrgAdmin - Failed to register Org Admin $admin to TLS Server"
    
    # Register Org admin with the CA server
    set -x
    fabric-ca-client register --mspdir ${FABRIC_CA_CLIENT_HOME}/${ORG_NAME}-ca/${CA_ADMIN}/msp -u https://${CA_ENDPOINT} --id.name $admin --id.secret $adminpw --id.type admin --caname ca-${ORG_NAME} --tls.certfiles $TLS_ROOTCERT_PATH  
    res=$?
    set +x
    verifyResult $res "registerOrgAdmin - Failed to register Org Admin $admin to CA Server"

    # Successful registration message
    printSuccess "registerOrgAdmin - Org Admin $admin registered to TLS and CA Sever successfully"
}

# Function: enrollOrgAdmin
# Description: Enroll the organization's admin to acquire the organization's MSP.
enrollOrgAdmin() {
    # Check if the ORG_NAME variable is set
    if [ -z "${ORG_NAME}" ]; then
        printError "enrollOrgAdmin - No organization specified"
        exit 1
    fi

    # Ensure the type is either 'peer' or 'orderer'
    if [ "${TYPE}" != "peer" ] &&  [ "${TYPE}" != "orderer" ]; then
        printError "enrollOrgAdmin - Not supported type of org: ${TYPE}"
        exit 1
    fi

    # Inform about the enrollment initiation
    printInfo "enrollOrgAdmin - Enroll the Admin of ${ORG_NAME}"

    # Define MSP/TLS paths
    ORG_HOME=${FABRIC_HOME}/organizations/"${TYPE}"Organizations/${ORG_NAME}.dt4h.com
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
	mkdir "${CAMSPDIR}"/tlscacerts && cp "${TLSMSPDIR}"/tlscacerts/cacert.pem "${CAMSPDIR}"/tlscacerts/cert.pem 
	
	res=$?
	verifyResult "$res" "enrollOrgAdmin - Failed to copy TLS Root-Cert to ${ORG_NAME} MSP"

	createNodeOUs "${CAMSPDIR}"

	# Create an MSP folder to import to System Config, which should not include private key
	[ ! -d ${MSP_CONFIG} ] && mkdir ${MSP_CONFIG}
	cp -r "$CAMSPDIR"/. ${MSP_CONFIG}
	rm -r ${MSP_CONFIG}/keystore
	rm -r ${MSP_CONFIG}/signcerts
    printSuccess "enrollOrgAdmin - Org admin enrolled to TLS and CA Server successfully"
}
