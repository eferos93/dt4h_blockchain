#!/bin/bash

# Execute a command to all Virtual Machine hosts
cmdAll() {
	local cmd="$@"
	
	if [ -z "$cmd" ]; then
		printError "No command given"
		exit 1
	fi
	
	echo
	echo
	echo "Command is: $cmd"
	echo
	echo

	IP_ARRAY_LEN=${#VM_IPS[@]}

	for (( i = 0; i < IP_ARRAY_LEN; i++ )); do
		echo -e "Requesting to ${VM_IPS[$i]}..."
		ssh -i ${SSH_KEY_PATH} ${VM_USER}@${VM_IPS[$i]} "cd ~/workspace/deploy >/dev/null || mkdir -p ~/workspace/deploy && cd ~/workspace/deploy && $cmd"
	done

}
