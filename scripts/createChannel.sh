#!/bin/bash

. api/peerAPI/channelOSNJoin.sh

joinOrderers() {
	
	for org in $ORDERER_ORGS; do
		setPorts "$org"
		for orderer in $ORDERER_IDS; do
			./peer.sh osnjoin -t orderer -n ${orderer}.$org.domain.com -p ${PORT_MAP[$orderer]}
		done
	done
	
}

createChannelA() {

	if [ -z "$1" ]; then 
		printError "No orgs specified."
		return
	fi

	orgs=$1
	mainOrg=$(echo $orgs | head -n1 | cut -d " " -f1)

	./peer.sh createchanneltx -c ${CHANNEL_NAME} -P ${CHANNEL_PROFILE}
	verifyResult $? "createChannelA - Failed to create channel tx. Exiting..." || return $?

	joinOrderers
	sleep 2

	set +x
	for org in $orgs; do
		ORG_MSP="$(echo "${org:0:1}" | tr '[:lower:]' '[:upper:]')${org:1}"MSP
		# sleep 3
		# ./peer.sh fetchconfig -n peer0."$org".domain.com
		# ./peer.sh updateanchorpeers -o "$org" -O "$ORG_MSP"
		# sleep 3
		# ./peer.sh channelupdate -n peer0.$org.domain.com -A
		./peer.sh joinchannel -n peer0."$org".domain.com -A 
		./peer.sh joinchannel -n peer1."$org".domain.com -A 
	done

}

