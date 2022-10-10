#!/bin/bash

export ORG_NAME=$1
setParams "$ORG_NAME"

set -e
createOrg() {
	# Set parameters
	export ORG_TYPE=PEER

	# Create CAs
	./clientCA.sh setup_orgca -o "$ORG_NAME"
	./clientCA.sh setup_orgmsp -o "$ORG_NAME" -t peer
	./clientCA.sh setup_orgops -o "$ORG_NAME"
}

createNodes() {
	# Reg-en peer
	./clientCA.sh register -t peer -u peer0 -o "$ORG_NAME" -s "$peerpw"
	./clientCA.sh enroll -t peer -u peer0 -o "$ORG_NAME" -s "$peerpw"

	# Register admin
	./clientCA.sh register -t admin -u "$admin" -o "$ORG_NAME" -s "$adminpw"
	./clientCA.sh enroll -t admin -u "$admin" -o "$ORG_NAME" -s "$adminpw"

	# Create Org-Users Admin which will be used to register users in the app as a registrar
	createOrgUsersAdmin "$ORG_NAME" "$admin"

	# Create a block listener client for the app
	./clientCA.sh register -t client -u "$blockclient" -o "$ORG_NAME" -s "$blockclientpw"
	./clientCA.sh enroll -t client -u "$blockclient" -o "$ORG_NAME" -s "$blockclientpw"

	./clientCA.sh regen_ops -t client -u "$prometheus" -o "$ORG_NAME" -s "$prometheuspw"
	PROMETHEUS_PATH=organizations/peerOrganizations/${ORG_NAME}.domain.com/users/prometheus
	tar -czvf "$FABRIC_HOME"/prometheus.tar.gz "$PROMETHEUS_PATH"
}

startNodes() {
	./peer.sh start -t peer -n peer0."$ORG_NAME".domain.com -p 10070 -D 7100
}

docker container rm -vf tlsca_${ORG_NAME} ca_${ORG_NAME}
sudo rm -rf organizations/fabric-ca/${ORG_NAME}
sudo rm -rf organizations/peerOrganizations/${ORG_NAME}.domain.com
cp -r ${FABRIC_CA_CFG_PATH}/${ORG_NAME}/* ${FABRIC_CA_CFG_PATH}/

createOrg 
createNodes 
startNodes

######### TRANSFERS ORG DEFINITION TO AN ORG ALREADY JOINED 
######### FOLLOWING IS FROM ANOTHER ORG
./peer.sh fetchconfig -n peer0.lynkeus.domain.com -o lynkeus

# Modify the configuration to append the new org
./peer.sh addorgupdate -O ${ORG_NAME^}MSP

./peer.sh signconfigtx -n peer0.tex.domain.com -A
./peer.sh channelupdate -n peer0.lynkeus.domain.com -A

######### New Org
./peer.sh fetchconfig -n peer0.${ORG_NAME}.domain.com -o ${ORG_NAME}
./peer.sh updateanchorpeers -o ${ORG_NAME} -O ${ORG_NAME}^MSP
./peer.sh channelupdate -n peer0.${ORG_NAME}.domain.com -A

