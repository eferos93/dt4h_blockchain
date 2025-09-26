#!/bin/bash

# Description: This functionality is used to export a node MSP to a tar.gz file to be transferred across VMs easily

printExportNodeHelp() {
	echo
	echo -e "./tools.sh exportNode orgName orgType nodeName [is_client]"
	echo 
	echo -e "Arguments:"
	echo -e "	orgName -- The name of the organization, e.g. myorg"
	echo -e "	orgType -- The type of the organization, peer/orderer"
	echo -e "	nodeName -- The name of the node, e.g peer0.org1.dt4h.com"
	echo -e "	is_client -- True if the member is a client (non node)"
	echo ""
	echo "Example:"
	echo -e "	./tools.sh exportNode ordererorg orderer orderer0.ordererorg.dt4h.com"
	echo -e "	./tools.sh exportNode org peer blockclient true"
	echo
}

# Export a Node's MSP to a compressed file
exportNode() {
	PEER=peer
	ORDERER=orderer
	CLIENTS=users

	# User Input
	org=$1
	orgType=$2
	nodeName=$3
	is_client=$4

	# Paths
	tarDest=${nodeName}.tar.gz
	orgPath=organizations/"$orgType"Organizations/${org}.dt4h.com
	if "$USERS"; then
		nodePath=$orgPath/$org-users/users/$nodeName
	elif "$is_client"; then
		nodePath=$orgPath/users/$nodeName
	else
		nodePath=$orgPath/${orgType}s/$nodeName
	fi

	if [ ! "$orgType" == $PEER ] && [ ! "$orgType" == $ORDERER ]; then
		printError "Wrong type of organization: $orgType"
		printExportNodeHelp
		exit 1	
	fi

	if [ ! -d  "$orgPath" ]; then
		printError "Organization: $org does not exist"
		printExportNodeHelp
		exit 1
	fi

	if [ ! -d  "$nodePath" ]; then
		printError "Node: ${nodeName} does not exist"
		echo "$nodePath"
		printExportNodeHelp
		exit 1
	fi

	if [ -z "$nodeName" ]; then
		printError "Node username is not specified"
		printExportNodeHelp
		exit 1
	fi

	tar -czvf "$tarDest" "$nodePath"
}
