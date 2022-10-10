#!/bin/bash

createChannelA() {

	if [ -z "$1" ]; then 
		printError "No orgs specified."
		return
	fi

	orgs=$1
	mainOrg=$(echo $orgs | head -n1 | cut -d " " -f1)

	set -x
	./peer.sh createchanneltx -c ${CHANNEL_NAME} -P ${CHANNEL_PROFILE}
	./peer.sh createchannel -n peer0.lynkeus.domain.com -c ${CHANNEL_NAME} -A
	set +x
	for org in $orgs; do
		ORG_MSP="${org^}"MSP
		# sleep 3
		./peer.sh fetchconfig -n peer0."$org".domain.com
		./peer.sh updateanchorpeers -o "$org" -O "$ORG_MSP"
		sleep 3
		./peer.sh channelupdate -n peer0.$org.domain.com -A
		./peer.sh joinchannel -n peer0."$org".domain.com -A 
		./peer.sh joinchannel -n peer1."$org".domain.com -A 
	done

}

