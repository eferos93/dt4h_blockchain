#!/bin/bash

. configGlobals.sh
. util.sh

######### 			 		######### 
######### 	RENEW 	CERT 	######### 
######### 			  		#########

# channels="system-channel athlynk"
channel=system-channel
# channel=athlynk

org=ordererorg
# org=texorderer

orderer=orderer0
# orderer=orderer1

timeshake=120h

######### 				  ######### 
######### UPDATE CHANNELS ######### 
######### 				  ######### 

# FOR EVERY CHANNEL, UPDATE ORDERER TLS CERT IN CHANNEL CONFIG

# FETCH CHANNEL CONFIG
./peer.sh fetchconfig -c $channel -t orderer -n ${orderer}.${org}.domain.com -A --tlshandshake $timeshake

# CREATE UPDATE CONFIG
./peer.sh updateorderertls -c $channel -n peer0.lynkeus.domain.com --orderer-id ${orderer}.${org}.domain.com

# SIGN ACCORDING TO POLICY
./peer.sh signconfigtx -n peer0.tex.domain.com -A
./peer.sh signconfigtx -n peer0.lynkeus.domain.com -A

# SUBMIT CHANNEL UPDATE
./peer.sh channelupdate -c $channel -t orderer -n ${orderer}.${org}.domain.com -A --tlshandshake $timeshake

# docker restart ${orderer}.${org}.domain.com
# sleep 5

# Verify
sleep 15
./peer.sh fetchconfig -c $channel -t orderer -n ${orderer}.${org}.domain.com -A
diff ${CHANNEL_ARTIFACTS}/config.yaml ${CHANNEL_ARTIFACTS}/modified_config.yaml
[ $? -ne 0 ] && printError "Error on updating channel configuration (Orderers TLS)"
