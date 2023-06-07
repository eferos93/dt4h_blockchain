#!/bin/bash

# Transfer files to all Virtual Machine hosts
transferAll() {
	FILE=$1
	DEST=/home/$VM_USER/workspace/deploy/$2
	DELETE=$3

	if [ -z "$FILE" ]; then
		printError "No file given to transfer"
		exit 1
	fi

	echo
	echo "File is: $FILE"
	echo "Dest is: $DEST"
	echo


	[[ ! -z $VM ]] && echo "Set VM Host: $VM"
	[[ ! -z $VM ]] && VM_IPS=("$(getent hosts $VM |  tr -s ' ' | cut -d " " -f 1)")

	IP_ARRAY_LEN=${#VM_IPS[@]}

	exclude="--exclude smpc-application --exclude bin --exclude organizations --exclude .git"
	# exclude+=" --exclude application-typescript"
	exclude+=" --exclude application-typescript/identities"
	exclude+=" --exclude chaincode/mhmdCC/mhmdCC"
	exclude+=" --exclude blockchain-explorer"
	exclude+=" --exclude application-typescript/node_modules --exclude application-typescript/kraken-app/docs --exclude application-typescript/kraken-app/jsdoc"
	exclude+=" --exclude chaincode-docker-devmode"
	exclude+=" --exclude logs --exclude grpc-comms --exclude prometheus --exclude share"
	exclude+=" --exclude system-genesis-block"
	for (( i = 0; i < IP_ARRAY_LEN; i++ )); do
		echo -e "Sending to ${VM_IPS[$i]}..."
		# set -x
		set -x
		rsync --update -ahv --info=progress2  $exclude "$FILE" "$VM_USER"@${VM_IPS[$i]}:"$DEST"
		set +x
		res=$?
		# set +x
		echo "Exit status: $?"
	done
}
