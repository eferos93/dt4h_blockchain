#!/bin/bash

# Export essential folders of fabric for deployment
exportFolder() {
	EXPORT_PATH=~/Desktop/deploy
	FABRIC_PATH=${PWD}

	EXPORT_FOLDERS="api chaincode config* scripts tests application-typescript"
	EXPORT_FILES="ccp.yaml *.sh DEPLOY.md README.md Makefile"

	mkdir $EXPORT_PATH
	set -x
	cp -r $EXPORT_FOLDERS $EXPORT_PATH
	cp $EXPORT_FILES $EXPORT_PATH
	set +x


	# APP_PATH=${EXPORT_PATH}/application-typescript
	# pushd ${FABRIC_PATH}/application-typescript || exit
	# cp -r scripts $APP_PATH
	# rsync -av kraken-app $APP_PATH --exclude kraken-app/msp --exclude kraken-app/docs --include '*.js' --include 'package.json' --include '*.md'
	# cp *.js *.sh .env $APP_PATH
	# cp README.md package.json $APP_PATH
	# popd || exit

}