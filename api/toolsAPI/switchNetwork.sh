#!/bin/bash

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

	CONFIG=config-"$NET"

	cp -f "$CONFIG"/configGlobals.sh "$FABRIC_HOME"
	cp -f "$CONFIG"/ccp.yaml "$FABRIC_HOME"
	cp -f "$CONFIG"/.env "$APP_PATH"

	set -x
	rsync -avP  "$CONFIG"/ "$FABRIC_HOME"/config/
	set +x
	printSuccess "Network switched to $NET"
}	