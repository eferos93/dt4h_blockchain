#!/bin/bash

. util.sh
. configCC.sh
. configGlobals.sh

for f in ${FABRIC_PEER_API}/*; do source $f; done

usage() {
	echo -e "Perform peer operations"
	echo -e "It is advised to set the variables in configCC.sh"
	echo 
	echo -e "Usage:"
	echo -e " ./peer.sh [command] [flags]"
	echo 
	echo -e "Available commands:"
	echo -e "  fetchconfig \t\t Fetch configuration of channel"
	echo -e "  channelupdate \t Perform a channel update with a configuration transaction"
	echo -e "  addorgupdate \t\t Create a configuration update transaction to add an organization"
	echo -e "  createchanneltx \t Creates a channel transaction from profile config"
	echo -e "  createchannel \t Submit channel transaction to orderer"
	echo -e "  osnjoin \t Add orderer to channel"
	echo -e "  joinchannel \t \t Joins a peer to channel"
	echo -e "  updateanchorpeers \t Create and submit anchor peer update transaction"
	echo -e "  listchannel \t \t List channels a peer has joined"
	echo -e "  package \t \t Package a chaincode"
	echo -e "  install \t\t Install chaincode to peer"
	echo -e "  queryinstalled \t Query installed chaincodes on peer "
	echo -e "  approve \t\t Approve chaincode as Org"
	echo -e "  queryapproved \t Query approved chaincodes on channel"
	echo -e "  checkreadiness \t Check commit readiness of chaincode"
	echo -e "  commit \t\t Commit chaincode definition to channel"
	echo -e "  querycommitted \t Query committed chaincodes on channel"
	echo -e "  signconfigtx \t\t Sign configuration transaction as organization"
	echo -e "  start \t\t Start a node, peer/orderer"
	echo -e "  crlupdate \t\t Compute channel CRL configuration update for OrgMSP"
	echo -e "  autocrlupdate \t\t Continuously update Org's CRL and commit Channel Update"
	echo -e "  addOrdererTLSCertsUpdate \t\t Create configuration update for Orderer TLS Certificate"
	echo -e "  computeUpdate \t\t Create new updated configuration"
	echo -e "  invoke \t\t Invoke a chaincode function"
	echo -e "  updateBlockchainRevokedCertificates \t\t Calls ManagementContract:UpdateCRL to store CRL"
	echo -e ""
	echo -e "Flags:"
	echo -e "  -n --peer \t\tPeer to set for operation in full name, e.g. peer0.org.domain.com"
	echo -e "  -p --port \t\tPort node is listening at"
	echo -e "  -s --cc-name \t\tChaincode name"
	echo -e "  -c --channel-id \tChannel ID of operation, e.g. athlynk"
	echo -e "  -f --config-path \t\tPath to configtx.yaml, defaults to FABRIC_CFG_PATH"
	echo -e "  -t --type \t\t Type of node peer/orderer"
	echo -e "  -P --profile \t\tChannel profile from configtx.yaml to use on channel TX creation"
	echo -e "  -O --org-mspid \tOrganization's MSPID as defined in configtx.yaml"
	echo -e "  -D --db-port \tPort of Couch DB the instance will start"
	echo -e "  -A --asadmin \t\tPerforms a peer operation as an admin"
	echo -e "  -x --tx \t\t Transaction to sign"
	echo -e "     --orderer-id \t\t Full Orderer ID e.g. orderer0.ordererorg.domain.com"
	echo -e "  -h --help \t\tPrint help message"
	echo -e ""
	echo -e "Examples:"
	echo -e "  ./peer.sh createchanneltx -c athlynk -P AthLynkChannel"
	echo -e "  ./peer.sh joinchannel -n peer1.org.domain.com -A "
	echo -e "  ./peer.sh queryinstalled -n peer1.org.domain.com"
	echo -e "  ./peer.sh commit -n peer1.org.domain.com"
	echo -e "  ./peer.sh install -n peer1.org.domain.com"
	echo -e "  ./peer.sh start -t peer -n peer1.org.domain.com -p 7050 -D 5984"
	echo -e "  ./peer.sh addorgupdate -O Org3MSP" 
	echo -e "  ./peer.sh updateanchorpeers -o org1 -O Org1MSP"
	echo -e "  ./peer.sh autocrlupdate -o org1"
	echo -e "  ./peer.sh invoke -x \'{"Args":["UserContract:ReadUser", "Alex"]}\'"

	echo -e ""
}

# Parse input
if [ $# -lt 1 ]; then
	usage
	exit 1
else
	MODE="$1"
fi

if [[ $# -ge 1 ]] ; then
	if [ "$MODE" == "createchanneltx" ]; then
		cmd=createChannelTx
	elif [ "$MODE" == "createchannel" ]; then
		cmd=createChannel
	elif [ "$MODE" == "updateanchorpeers" ]; then
		cmd=addAnchorPeerUpdate
	elif [ "$MODE" == "joinchannel" ]; then
		cmd=joinChannel
	elif [ "$MODE" == "listchannel" ]; then
		cmd=channelList
	elif [ "$MODE" == "package" ]; then
		cmd=packageCC
	elif [ "$MODE" == "install" ]; then
		cmd=installCC
	elif [ "$MODE" == "queryinstalled" ]; then
		cmd=queryInstalled
	elif [ "$MODE" == "approve" ]; then
		cmd=approveCC
	elif [ "$MODE" == "queryapproved" ]; then
		cmd=queryApproved
	elif [ "$MODE" == "checkreadiness" ]; then
		cmd=checkCommitReadiness
	elif [ "$MODE" == "commit" ]; then
		cmd=commitChaincodeDefinition
	elif [ "$MODE" == "querycommitted" ]; then
		cmd=queryCommitted
	elif [ "$MODE" == "fetchconfig" ]; then
		cmd=fetchChannelConfig
	elif [ "$MODE" == "addorgupdate" ]; then
		cmd=addOrgUpdate		
	elif [ "$MODE" == "signconfigtx" ]; then
		cmd=signConfigtxAsPeerOrg		
	elif [ "$MODE" == "channelupdate" ]; then
		cmd=channelUpdate
	elif [ "$MODE" == "start" ]; then
		cmd=startNode
	elif [ "$MODE" == "crlupdate" ]; then
		cmd=addCrlUpdate 	
	elif [ "$MODE" == "autocrlupdate" ]; then
		cmd=updateCRL
	elif [ "$MODE" == "updateorderertls" ]; then
		cmd=addOrdererTLSCertsUpdate
	elif [ "$MODE" == "computeupdate" ]; then
		cmd=computeUpdate
	elif [ "$MODE" == "invoke" ]; then
		cmd=invoke
	elif [ "$MODE" == "autocrlupdatecontract" ]; then
		cmd=updateBlockchainRevokedCertificates
	elif [ "$MODE" == "osnjoin" ]; then
		cmd=osnChannelJoin
	else
		usage
		exit 1
	fi
	shift
fi

while [[ $# -ge 1 ]]; do
	key=$1
	case $key in
	-h )
		usage
		exit 0	
		;;
	-n|--peer )
		export ORG_NAME="$(echo $2 | cut -d "." -f 2)"
		# export ID="$(echo $2 | cut -d "." -f 1 | sed 's/[^0-9]*//g')"
		export NODE_ID="$(echo $2 | cut -d "." -f 1)"
		[ $? -eq 1 ] && exit 1
		;;
	-c|--channel-id )
		export CHANNEL_NAME=$2
		;;	
	-s|--cc-name )
		export CC_NAME=$2
		;;
	-P|--profile )
		export CHANNEL_PROFILE=$2
		;;	
	-O|--org-mspid )
		export ORG_MSPID=$2
		;;		
	-o|--org )
		export ORG_NAME=$2
		;;	
	-f|--config-path )
		export CONFIG_PATH=$2
		;;
	-p|--port )
		export NODE_PORT=$2
		;;	
	-x|--tx )
		export TX=$2
		;;
	-t|--type )
		export TYPE=$2
		;;
	-D|--db-port )
		export DB_PORT=$2
		;;
	-U|--users )
		export USERS=true
		;;
	-A|--as-admin )
		export ADMIN=true
	    ;;
	--tlshandshake )
		export TLSHANDSHAKETIMESHIFT="--tlsHandshakeTimeShift $2"
		;;
	--orderer-id )
		export ORDERER_ID=$2
		export ORDERER_ORG="$(echo $ORDERER_ID | cut -d "." -f2-)"
		;;
	esac
	shift 
done


setPeer "$ORG_NAME" "$NODE_ID"

[ ! -z $ADMIN ] && export CORE_PEER_MSPCONFIGPATH=${FABRIC_HOME}/organizations/peerOrganizations/${ORG_NAME}.domain.com/users/${ADMIN_USER}/msp
[ ! -z $ADMIN ] && [[ $TYPE == 'orderer' ]] && export CORE_PEER_MSPCONFIGPATH=${FABRIC_HOME}/organizations/ordererOrganizations/${ORG_NAME}.domain.com/users/${ADMIN_USER}/msp && export CORE_PEER_LOCALMSPID=$(echo "${ORG_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${ORG_NAME:1}MSP
[ ! -z $USERS ] && export ORG_MSPID="$(echo "${ORG_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${ORG_NAME:1}UsersMSP"
[ -z $USERS ] && export ORG_MSPID="$(echo "${ORG_NAME:0:1}" | tr '[:lower:]' '[:upper:]')${ORG_NAME:1}MSP"


$cmd


