#!/bin/bash

# Script: Deploy Chaincode to Channel 
queryCC() {
	setPeer $1 peer0
	printInfo "Querying chaincode..."

	local rc=1
	local COUNTER=1

	funcCall='{"Args":["UserContract:ReadUser", "user1"]}'
	funcCall='{"Args":["UserContract:GetAllUsers"]}'
	funcCall='{"Args":["DataContract:GetAllProducts"]}'
	while [ $rc -ne 0 -a $COUNTER -lt $MAX_RETRY ]; do
		set -x
		peer chaincode query -c "$funcCall" -C ${CHANNEL_NAME} -n ${CC_NAME} | jq >& log.txt
		res=$?
		set +x
		rc=$res
		COUNTER=$(expr $COUNTER + 1)
	done

	cat log.txt
}

invokeCC() {
	printInfo "Invoking chaincode..."
	setPeers "$peerOrgs"
	setPeer $1 peer1
	env | grep CORE

	funcCall='{"Args":["UserContract:CreateUser",   "{\n  \"username\": \"user2\",\n  \"isOrg\": true,\n  \"org\": {\n    \"instType\": \"Private Hospital\",\n    \"orgName\": \"orgexample\",\n    \"dpoFirstName\": \"Bob\",\n    \"dpoLastName\": \"Bobinson\",\n    \"dpoEmail\": \"Bob@email.com\",\n    \"active\": true\n  },\n  \"isBuyer\": true,\n  \"purposes\": [\n    \"Marketing\",\n    \"Business\"\n  ]\n}\n"  ]}'
	# funcCall='{"Args":["DataContract:CreateProduct", "{\n   \"name\":\"prodName1\",\n   \"price\":10,\n   \"desc\":\"A simple blood test.\",\n   \"policy\":{\n      \"inclPersonalInfo\":true,\n      \"hasconsent\":true,\n      \"purposes\":[\n         \"Marketing\",\n         \"Business\"\n      ],\n      \"protectionType\":\"SMPC\",\n      \"secondUseConsent\":true,\n      \"recipientType\":\"\",\n      \"transferToCountry\":false,\n      \"storagePeriod\":20\n   }\n}" ]}'
	set -x
	peer chaincode invoke -c "$funcCall" ${PEERS} -C ${CHANNEL_NAME} -n ${CC_NAME} -o ${ORDERER} --cafile ${ORDERER_CAFILE} --tls --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} >& log.txt
	res=$?
	set +x

	# verifyResult "$res" "$(cat log.txt)"
	printSuccess "$(cat log.txt)"
}

deployChaincode() {

	peerOrgs="$1"
	mainOrg=$(echo "$peerOrgs" | head -n1 | cut -d " " -f1)

	./peer.sh package -s ${CC_NAME}
	for org in $peerOrgs; do
		./peer.sh install -n peer0."$org".dt4h.com -A
		./peer.sh install -n peer1."$org".dt4h.com -A
		./peer.sh queryinstalled -n peer0."$org".dt4h.com -A
		./peer.sh approve -n peer0."$org".dt4h.com -A
		./peer.sh queryapproved -n peer0."$org".dt4h.com -A
		./peer.sh checkreadiness -n peer0."$org".dt4h.com -A
	done

	./peer.sh commit -n peer0."$mainOrg".dt4h.com -A
	./peer.sh querycommitted -n peer0."$mainOrg".dt4h.com -A
	sleep 3

	# chaincodeInit $mainOrg
	# queryCC $mainOrg
	# invokeCC $mainOrg
}