#!/bin/bash

# Enroll the CA Admin to the CA Server
enrollCAAdmin() {
	printInfo "enrollCAAdmin - Enrolling the CA Admins..."


	# Enroll the CA Admin to obtain the msp 
	set -x
	fabric-ca-client enroll -u https://${caadmin}:${caadminpw}@"${caendpoint}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --csr.hosts localhost,"$caHost" --mspdir "${ORG_NAME}"-ca/${caadmin}/msp --caname ca-${ORG_NAME}
	set +x
	res=$?
	verifyResult $res "enrollCAAdmin - Failed to enroll the CA Admin ${caadmin} to the CA Server at ${caendpoint}"
	
	echo
	set -x
	fabric-ca-client enroll -u https://${userscaadmin}:${userscaadminpw}@"${caendpoint}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --csr.hosts localhost,"$caHost" --mspdir "${ORG_NAME}"-users-ca/${userscaadmin}/msp --caname ca-${ORG_NAME}-users
	set +x
	res=$?
	verifyResult $res "enrollCAAdmin - Failed to enroll the Users CA Admin ${userscaadmin} to the CA Server at ${caendpoint}"

	echo
	mv "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-ca/${caadmin}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-ca/${caadmin}/msp/keystore/key.pem
	mv "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-users-ca/${userscaadmin}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-users-ca/${userscaadmin}/msp/keystore/key.pem
	res=$?
	verifyResult $res "enrollCAAdmin - Failed to rename the CA Admin files"
	printSuccess "enrollCAAdmin - CA Admin: ${caadmin} (UsersCA Admin): ${userscaadmin} enrolled successfully!"
}