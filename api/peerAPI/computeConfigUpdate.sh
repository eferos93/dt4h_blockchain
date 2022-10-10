#!/bin/bash

# Add anchor peers Update
addAnchorPeerUpdate() {
	printInfo "Creating new configuration - Updating Anchor Peers..."
	
	pushd ${CHANNEL_ARTIFACTS} || exit
	if [ -z "${ORG_MSPID}" ]; then
		printError "Organization MSPID is not defined"
		exit 1
	fi

	yq_out=$(cat ${FABRIC_CA_CFG_PATH}/configtx.yaml | yq)

	# echo 'yq_out' $yq_out
	jq_out=$(echo "$yq_out" | jq -s '.[].Organizations | map(select(.ID == "'"$ORG_MSPID"'")) | .[].AnchorPeers')
	ANCHOR_PEERS=( `echo $jq_out | jq `)
	# echo "$jq_out"  

	ANCHOR_PEERS=$(echo "${ANCHOR_PEERS[@]}" | awk '{print tolower($0)}' | tr -d [:space:])
	echo $ANCHOR_PEERS

	set -x
	# configtxgen -profile AthLynkChannel -outputAnchorPeersUpdate ${FABRIC_HOME}/channel-artifacts/${ORG_NAME}anchors.tx -channelID ${CHANNEL_NAME} -asOrg ${ORG_MSPID} >& log.txt
	jq '.channel_group.groups.Application.groups."'"$ORG_MSPID"'".values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": '"$ANCHOR_PEERS"'},"version": "0"}}' config.json > modified_config.json
	res=$?
	set +x

	computeUpdate
	verifyResult "$res" "Error adding anchor peers to modified_config" && printSuccess "Anchor Peer update transaction created successfully"
	
	popd
}


# Add organization Update
addOrgUpdate() {
	printInfo "Creating new configuration... - Adding new Organization"

	if [ -z "${ORG_MSPID}" ]; then
		printError "Organization MSPID is not defined"
		exit 1
	fi

	USE_PATH=
	if [ -n "${CONFIG_PATH}" ]; then
		USE_PATH="-configPath ${CONFIG_PATH}"
	fi

	pushd ${CHANNEL_ARTIFACTS} || exit

	set -x
	configtxgen ${USE_PATH} -printOrg "${ORG_MSPID}" > "${ORG_MSPID}".json
	res=$?
	set +x
	verifyResult $res "Error printing configuration of org: ${ORG_MSPID}"

	set -x
	jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'"$ORG_MSPID"'":.[1]}}}}}' config.json "${ORG_MSPID}".json > modified_config.json
	res=$?
	set +x
	verifyResult $res "Error modifying JSON config" 

	computeUpdate

	popd
}

# Renew CRL Update
addCrlUpdate() {
	printInfo "addCrlUpdate - Creating new configuration - Renewing CRL..."

	pushd ${CHANNEL_ARTIFACTS} || exit
	if [ -z "${ORG_MSPID}" ]; then
		printError "addCrlUpdate - Organization MSPID is not defined"
		exit 1
	fi

	set -e
	# Add new CRL to existing CRL array
	[ -f ${CHANNEL_ARTIFACTS}/crl64 ] || verifyResult 1 "${CHANNEL_ARTIFACTS}/crl64 not found"
	export CRL="$(cat ${CHANNEL_ARTIFACTS}/crl64)"

	set -x
	jq  '.channel_group.groups.Application.groups."'"$ORG_MSPID"'".values.MSP.value.config.revocation_list |= [env.CRL]' config.json > modified_config.json
	res=$?
	set +x
	verifyResult $res "addCrlUpdate - Error modifying JSON config" 

	computeUpdate

	popd
	printSuccess "addCrlUpdate - Configuration update created"
}

# Update Org MSP Certs
addRootCACertsUpdate() {
	printInfo "addRootCertsUpdate - Creating new configuration: Renewing Admin Certs for ${ORG_NAME}..."

	[ -z "$TYPE" ] && printError "Missing TYPE" && exit 1
	[ -z "$ORG_NAME" ] && printError "Missing ORG NAME" && exit 1

	pushd ${CHANNEL_ARTIFACTS} || exit

	NEW_CERT="$(cat ${FABRIC_HOME}/organizations/${TYPE}Organizations/${ORG_NAME}/mspConfig/cacerts/cacert.pem | base64 -w 0)"
	
	BASE=channel_group.groups.Application.groups."'"$ORG_MSPID"'".values.MSP.value.config
	[ "$CHANNEL_NAME" == 'system-channel' ] && BASE=channel_group.groups.Consortiums.groups."'"$CONSORTIUM_NAME"'".groups."'"$ORG_MSPID"'".values.MSP.value.config
	
	# Case PEER
	if [ "$TYPE" == "peer" ]; then
		set -x
		jq '."'$BASE'".root_certs = "'"$NEW_CERT"'"' config.json > modified_config.json
		jq '."'$BASE'".fabric_node_ous.admin_out_identifier.certificate |= "'"$NEW_CERT"'"' modified_config.json > modified_config.json
		jq '."'$BASE'".fabric_node_ous.client_ou_identifier.certificate |= "'"$NEW_CERT"'"' modified_config.json > modified_config.json
		jq '."'$BASE'".fabric_node_ous.orderer_ou_identifier.certificate |= "'"$NEW_CERT"'"' modified_config.json > modified_config.json
		jq '."'$BASE'".fabric_node_ous.peer_ou_identifier.certificate |= "'"$NEW_CERT"'"' modified_config.json > modified_config.json
		res=$?
		set +x
		verifyResult $res "addRootCertsUpdate - Error modifying JSON config" 	
	fi

	# Case ORDERER

	computeUpdate
	popd
	verifyResult $res "Error modifying JSON config" 
	printSuccess "addCertsUpdate - Configuration of new Admin Certs update created"
}

# Update Orderer/Consenter TLS Certs
addOrdererTLSCertsUpdate() {
	printInfo "addOrdererTLSUpdate - Modifying Orderer: ${ORDERER_ID} TLS Cert"

	pushd ${CHANNEL_ARTIFACTS} || exit

	NEW_TLS_CERT="$(cat ${FABRIC_HOME}/organizations/ordererOrganizations/${ORDERER_ORG}/orderers/${ORDERER_ID}/tls/signcerts/cert.pem | base64 -w 0)"

	set -x
	jq '.channel_group.groups.Orderer.values.ConsensusType.value.metadata.consenters[] |= if (.host=="'$ORDERER_ID'") then .client_tls_cert|="'$NEW_TLS_CERT'" | .server_tls_cert|="'$NEW_TLS_CERT'" else . end'  config.json > modified_config.json
	res=$?
	set +x

	computeUpdate
	popd
	verifyResult $res "Error modifying JSON config" 
	printSuccess "addOrdererTLSUpdate - Configuration update created"
}

# Compute the delta between the new and old configurations
computeUpdate() {
	OUTPUT=update_in_envelope.pb
	ORIGINAL=config.json
	MODIFIED=modified_config.json

	pushd ${CHANNEL_ARTIFACTS}
	printInfo "Computing update..."

	if [ ! -f "$ORIGINAL" ]; then
		printError "Original Config File ${ORIGINAL} does not exist."
		exit 1
	fi

	if [ ! -f "$MODIFIED" ]; then
		printError "Modified Config File ${MODIFIED} does not exist."
		exit 1
	fi

	configtxlator proto_encode --input "${ORIGINAL}" --type common.Config > original_config.pb
	res=$?
	verifyResult "$res" "Error computing update"

	configtxlator proto_encode --input "${MODIFIED}" --type common.Config > modified_config.pb
	res=$?
	verifyResult "$res" "Error computing update"

	configtxlator compute_update --channel_id "${CHANNEL_NAME}" --original original_config.pb --updated modified_config.pb > config_update.pb
	res=$?
	verifyResult "$res" "Error computing update"

	configtxlator proto_decode --input config_update.pb --type common.ConfigUpdate > config_update.json
	res=$?
	verifyResult "$res" "Error computing update" || exit 1

	echo '{"payload":{"header":{"channel_header":{"channel_id":"'${CHANNEL_NAME}'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' | jq . > config_update_in_envelope.json
	res=$?
	verifyResult "$res" "Error computing update" || exit 1

	configtxlator proto_encode --input config_update_in_envelope.json --type common.Envelope > "${OUTPUT}"
	res=$?
	verifyResult "$res" "Error computing update" || exit 1

	printSuccess "Configuration update created ${OUTPUT}"
	popd
}


# createConfigUpdate