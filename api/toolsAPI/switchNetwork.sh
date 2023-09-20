#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: Rotates the configurations from development to production

# Switch network configuration to 2 modes: Development - Production
switchNet() {
	printInfo "Switching environment..."

	PROD=prod
	DEV=dev

	NET=$1
	
	if [ -z "$NET" ]; then
		printError "No argument given. dev or prod?"
		exit 1
	fi
	
	if [[ "$NET" != "$DEV" && "$NET" != "$PROD" ]]; then
		printError "Wrong input. dev or prod?"
		exit 1
	fi

	CONFIG=config

	cp -f "$CONFIG"/configGlobals_"$NET".sh "$FABRIC_HOME"/configGlobals.sh
	cp -f "$CONFIG"/.env "$APP_PATH"

	# set -x
	# rsync -avP  "$CONFIG"/ "$FABRIC_HOME"/config/
	# set +x
	printSuccess "Network switched to $NET"
}	