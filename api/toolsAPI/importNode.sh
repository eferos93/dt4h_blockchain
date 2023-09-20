#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script provides functionality to import a node folder 

printImportNodeHelp() {
	echo
	echo -e "./tools.sh importNode filePath"
	echo 
	echo -e "Arguments:"
	echo -e "	filePath -- Path to peer.org.tar.gz file"
	echo
	echo "Example"
	echo -e "	./tools.sh importNode peer0.org1.domain.com.tar.gz"
	echo
}

importNode() {
	# User Input
	tarfile="$1"

	if [ ! -f "$tarfile" ]; then
		printError "File does not exist"
		printImportNodeHelp
		exit 1
	fi

	# Decompress
	tar -C "$FABRIC_HOME" -xzvf "$tarfile" 
}
