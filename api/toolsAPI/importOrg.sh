#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script provides functionality to import an Org MSP, exported from the exportFolder functionality.

printImportOrgHelp() {
	echo
	echo -e "./tools.sh importOrg filePath orgType"
	echo 
	echo -e "Arguments:"
	echo -e "	filePath -- The path to the org.tar.gz file"
	echo -e "	orgType -- The type of the organization, peer/orderer"
}

importOrg() {
	PEER=peer
	ORDERER=orderer

	# User Input
	tarfile=$1
	orgType=$2

	org="${tarfile%%.*}"
	orgDir="$(basename $tarfile .tar.gz)"
	orgPath=organizations/"$orgType"Organizations

	if [ ! "$orgType" == $PEER ] && [ ! "$orgType" == $ORDERER ]; then
		echo "Wrong type of organization: $orgType"
		printImportOrgHelp
		exit 1	
	fi

	if [ ! -f "$tarfile" ]; then
		echo "File does not exist"
		printImportOrgHelp
		exit 1
	fi

	# Decompress
	mkdir -p "$orgPath"
	tar -C "$orgPath" -xzvf "$tarfile" 
}