#!/bin/bash



##########################
# Enroll the CA Admin and Users CA Admin to the CA Server.
# Globals:
#   CA_ADMIN, CA_ADMINPW, USERSCA_ADMIN, USERSCA_ADMINPW, CA_ENDPOINT, 
#   ORG_NAME, caHost, FABRIC_CA_CLIENT_HOME
# Arguments:
#   None
# Returns:
#   None
##########################
enrollCAAdmin() {
	printInfo "enrollCA_ADMIN - Enrolling the CA Admins..."

	# Enroll the CA Admin to obtain its MSP
	set -x
	fabric-ca-client enroll -u https://${CA_ADMIN}:${CA_ADMINPW}@"${CA_ENDPOINT}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --csr.hosts localhost,"$caHost" --mspdir "${ORG_NAME}"-ca/${CA_ADMIN}/msp --caname ca-${ORG_NAME}
	set +x
	res=$?
	verifyResult $res "enrollCA_ADMIN - Failed to enroll the CA Admin ${CA_ADMIN} to the CA Server at ${CA_ENDPOINT}"
	
	echo

	# Enroll the Users CA Admin
	# set -x
	# fabric-ca-client enroll -u https://${USERSCA_ADMIN}:${USERSCA_ADMINPW}@"${CA_ENDPOINT}" --tls.certfiles tls-root-cert/tls-ca-cert.pem --csr.hosts localhost,"$caHost" --mspdir "${ORG_NAME}"-users-ca/${USERSCA_ADMIN}/msp --caname ca-${ORG_NAME}-users
	# set +x
	# res=$?
	# verifyResult $res "enrollCA_ADMIN - Failed to enroll the Users CA Admin ${USERSCA_ADMIN} to the CA Server at ${CA_ENDPOINT}"

	echo

	# Rename the key files for CA Admin and Users CA Admin
	mv "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-ca/${CA_ADMIN}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-ca/${CA_ADMIN}/msp/keystore/key.pem
	# mv "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-users-ca/${USERSCA_ADMIN}/msp/keystore/* "$FABRIC_CA_CLIENT_HOME"/"${ORG_NAME}"-users-ca/${USERSCA_ADMIN}/msp/keystore/key.pem
	res=$?
	verifyResult $res "enrollCA_ADMIN - Failed to rename the CA Admin files"
	printSuccess "enrollCA_ADMIN - CA Admin: ${CA_ADMIN} sucessfully!" #and Users CA Admin: ${USERSCA_ADMIN} enrolled successfully!"
}
