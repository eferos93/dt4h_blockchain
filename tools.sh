#!/bin/bash

. .env
. util.sh
. configGlobals.sh
. configCC.sh

for f in ${FABRIC_TOOLS_API}/*; do source $f; done

usage() {
	echo -e "Tools for file handling and remote connection operations"
	echo 
	echo -e "Usage:"
	echo -e " ./tools.sh [command] [args]"
	echo 	
	echo -e "Available commands:"
	echo -e "  switchNet \t Switch network configs: dev / prod"
	echo -e "  transferAll \t Transfer files to all VM Hosts"
	echo -e "  cmdAll \t Execute a command to all VM Hosts"
	echo -e "  configHosts \t Add Fabric Hosts to /etc/hosts"
	echo -e "  exportOrg \t Export the MSP(without keys) of an organization"
	echo -e "  importOrg \t Import the MSP of an organization"
	echo -e "  exportNode \t Export the MSP of a node"
	echo -e "  importNode \t Import the MSP of a node"
	echo -e "  exportFolder \t Export essential fabric folders for deployment"
	echo -e "  genccp \t Generate common connection profile"
	echo -e "  setup \t Setup Fabric Binaries and Golang on the machine"
	echo -e ""
	echo -e "Flags:"
	echo -e "  -U <users> \t\t Use org-users"
	echo -e "Examples:"	
	echo -e "	./tools.sh switchNet prod/dev"
	echo -e "	./tools.sh transferAll [file/dir] FABRIC_HOME/[dest]"
	echo -e "	./tools.sh cmdAll '[cmd]'"
	echo -e ""
}

if [ $# -lt 1 ]; then
	usage
	exit 1
else
	MODE="$1"
fi

if [[ $# -ge 1 ]]; then
	if [ "$MODE" == "switchNet" ]; then
		cmd="switchNet $2" 
	elif [[ "$MODE" == "transferAll" ]]; then
		cmd="transferAll $2 $3"
	elif [[ "$MODE" == "cmdAll" ]]; then
		shift
		cmd="cmdAll $@"
	elif [[ "$MODE" == "exportNode" ]]; then
		shift
		cmd="exportNode $@"
	elif [[ "$MODE" == "configHosts" ]]; then
		cmd="configHosts"
	elif [[ "$MODE" == "exportOrg" ]]; then
		shift
		cmd="exportOrg $@"
	elif [[ "$MODE" == "importNode" ]]; then
		shift
		cmd="importNode $@"
	elif [[ "$MODE" == "importOrg" ]]; then
		shift
		cmd="importOrg $@"
	elif [[ "$MODE" == "exportFolder" ]]; then
		cmd="exportFolder"
	elif [[ "$MODE" == "genccp" ]]; then
		cmd="generateCCP"
	elif [[ "$MODE" == "setup" ]]; then
		cmd="setup"
	elif [[ "$MODE" == "sync" ]]; then
		# cmd="sync"
		EXPORT_FOLDERS="api chaincode config* scripts tests application-typescript"
		EXPORT_FILES="*.sh DEPLOY.md README.md Makefile"
		EXCLUDE=" --exclude application-typescript/node_modules --exclude config-prod/organizations --exclude config.backup"
		EXCLUDE+=" --exclude application-typescript/identities --exclude application-typescript/wallet --exclude application-typescript/lynkeusRegistrar --exclude application-typescript/nextblock"
		EXCLUDE+=" --exclude application-typescript/kraken-app/jsdoc"
		rsync -av --update  $EXPORT_FOLDERS $EXPORT_FILES $EXCLUDE athena@bcms:/home/athena/workspace/deploy
	else
		echo "Command not found"
		usage
		exit 1
	fi
fi

while [[ $# -ge 1 ]]; do
	key=$1
	case $key in
	-U|--users )
		export USERS=true
		;;
	esac
	shift
done

$cmd

