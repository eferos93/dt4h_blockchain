#!/bin/bash

printExportOrgHelp() {
	echo
	echo -e "./tools.sh exportOrg orgName orgType"
	echo 
	echo -e "Arguments:"
	echo -e "	orgName -- The name of the organization, e.g myorg"
	echo -e "	orgType -- The type of the organization, peer/orderer"
}


exportOrg() {
	PEER=peer
	ORDERER=orderer

	# User Input
	org=$1
	orgType=$2

	# Name of Dir
	orgDir=${org}.domain.com
	orgPath=organizations/"$orgType"Organizations/${org}.domain.com

	if [ ! "$orgType" == $PEER ] && [ ! "$orgType" == $ORDERER ]; then
		echo "Wrong type of organization: $orgType"
		printExportOrgHelp
		exit 1	
	fi

	if [ ! -d  "$orgPath" ]; then
		echo "Org $org does not exist"
		printExportOrgHelp
		exit 1
	fi
		
	rsync -av "$orgPath"/mspConfig "$orgDir"
	rsync -av "$orgPath"/usersmsp "$orgDir"

	tar -czvf "$orgDir".tar.gz "$orgDir"
	rm -rf "$orgDir"
}
