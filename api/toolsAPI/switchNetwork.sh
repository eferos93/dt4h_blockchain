#!/bin/bash

# Switch network configurations to 2 modes: Development - Production
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
	# if [[ "$NET" == "dev" ]]; then
	# 	cp -r organizations "config_$DEV"/
	# fi
	
	# cp -rf "$CONFIG"/organizations "$FABRIC_HOME"

	set -x
	rsync -avP  "$CONFIG"/ "$FABRIC_HOME"/config/
	set +x
	printSuccess "Network switched to $NET"
}	