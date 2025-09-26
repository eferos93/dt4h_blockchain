#!/bin/bash


# Export essential folders of fabric for deployment
exportFolder() {
	EXPORT_PATH=${EXPORT_DEPLOYMENT_DIRECTORY}
	FABRIC_PATH=${PWD}

	EXPORT_FOLDERS="api chaincode config* scripts tests application-typescript"
	EXPORT_FILES="*.sh DEPLOY.md README.md Makefile"

	mkdir $EXPORT_PATH
	set -x
	cp -r $EXPORT_FOLDERS $EXPORT_PATH
	cp $EXPORT_FILES $EXPORT_PATH
	set +x

}