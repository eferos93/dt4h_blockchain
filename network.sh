#!/bin/bash

# This script brings up a Hyperledger Fabric Network
[ ! -d logs ] && mkdir logs

. util.sh
. configGlobals.sh
. configCC.sh
. scripts/createUsersAdmin.sh
. scripts/createChannel.sh
. scripts/deployCC.sh

[ ! -d ${CHANNEL_ARTIFACTS} ] && mkdir channel-artifacts

# Start the network
networkUp() {
	printHead "Bringing up the network"

  # set -e
	createOrgs 
	createNodes
	createConsortium
	startNodes
	rm -rf channel-artifacts
	createChannel
	deployCC
	exportMSPs
	setupMonitor

	docker ps -a
}

# Create Orgs, Register and Enroll TLS,CA and Org Admins
createOrgs() {
	printInfo "Setting up CAs - Org MSPs"

	if [ -d ${FABRIC_HOME}/organizations ]; then
		printError "Orgs exist. Exiting..."
		exit 0
	fi

	mkdir -p docker organizations/fabric-ca 

	for org in $ORDERER_ORGS; do
		setParams "$org"
		./clientCA.sh setup_orgca -o "$org"
		./clientCA.sh setup_orgmsp -o "$org" -t "orderer"
		./clientCA.sh setup_orgops -o "$org"
	done

	for org in $PEER_ORGS; do
		setParams "$org"
		./clientCA.sh setup_orgca -o "$org"
		./clientCA.sh setup_orgmsp -o "$org" -t "peer"
		./clientCA.sh setup_orgops -o "$org"
	done

	printSuccess "Organizations created successfully"
}

# Create Orderers and Peers
createNodes() {
	printInfo "Register and enroll orderers and peers"

	for org in $ORDERER_ORGS; do
		setParams "$org"

		# Register enroll orderers
		for orderer in $ORDERER_IDS; do
			./clientCA.sh register -t orderer -u "$orderer" -o "$org" -s "$ordererpw"
			./clientCA.sh enroll -t orderer -u "$orderer" -o "$org" -s "$ordererpw"
		done

		# Register admin
		./clientCA.sh register -t admin -u "$admin" -o "$org" -s "$adminpw"
		./clientCA.sh enroll -t admin -u "$admin" -o "$org" -s "$adminpw"

		# Enroll an Operations Client to monitor nodes securely
		./clientCA.sh regen_ops -t client -u "$prometheus" -o "$org" -s "$prometheuspw"

		PROMETHEUS_PATH=organizations/ordererOrganizations/${org}.domain.com/users/prometheus
		tar -czvf "$FABRIC_HOME"/prometheus.tar.gz "$PROMETHEUS_PATH"
	done

	for org in $PEER_ORGS; do
		setParams "$org"

		# Register enroll peers
		for peer in $PEER_IDS; do
			./clientCA.sh register -t peer -u "$peer" -o "$org" -s "$peerpw"
			./clientCA.sh enroll -t peer -u "$peer" -o "$org" -s "$peerpw"
		done

		# Register admin
		./clientCA.sh register -t admin -u "$admin" -o "$org" -s "$adminpw"
		./clientCA.sh enroll -t admin -u "$admin" -o "$org" -s "$adminpw"

		# Create Org-Users Admin which will be used to register users in the app as a registrar
		createOrgUsersAdmin "$org" "$admin"

		# Create a block listener client for the app
		./clientCA.sh register -t client -u "$blockclient" -o "$org" -s "$blockclientpw"
		./clientCA.sh enroll -t client -u "$blockclient" -o "$org" -s "$blockclientpw"

		# Enroll an Operations Client to monitor nodes securely
		./clientCA.sh regen_ops -t client -u "$prometheus" -o "$org" -s "$prometheuspw"

		PROMETHEUS_PATH=organizations/peerOrganizations/${org}.domain.com/users/prometheus
		tar -czvf "$FABRIC_HOME"/prometheus.tar.gz "$PROMETHEUS_PATH"
	done

	printSuccess "Orderers and peers enrolled"
}

# Create the Orderer Genesis block
createConsortium() {
	printInfo "Generating Orderer Genesis Block"

	
	if [ "$(which configtxgen)" -ne 0 ]; then
		printError "Tool configtxgen does not exist."
		exit 1
	fi

	set -x
	configtxgen -profile OrdererGenesis -channelID system-channel -outputBlock ./system-genesis-block/genesis.block
	res=$?
	set +x

	verifyResult "$res" "Genesis block failed to generate"
	printSuccess "Orderer genesis block generated!"
}

# Bring up the nodes
startNodes() {
	printInfo "Starting nodes"

	for org in $ORDERER_ORGS; do
		setPorts "$org"
		for orderer in $ORDERER_IDS; do
			./peer.sh start -t orderer -n "$orderer"."$org".domain.com -p "${PORT_MAP[${orderer}]}"
		done
	done

	local COUNT=0
	for org in $PEER_ORGS; do
		setPorts "$org"
		for peer in $PEER_IDS; do
			./peer.sh start -t peer -n "$peer"."$org".domain.com -p "${PORT_MAP[${peer}]}" -D "${COUCHDB_PORTS[${COUNT}]}"
			((COUNT++))
		done
	done

	printSuccess "Nodes are up and running!"
}

# Create a channel
createChannel() {
	printInfo "Creating Channel ${CHANNEL_NAME}"

	createChannelA "$PEER_ORGS"
	res=$?
	verifyResult "$res" "Channel creation failed!"
	
	printSuccess "Channel ${CHANNEL_NAME} Created!"
}

# Deploy chaincode
deployCC() {
	printInfo "Deploy Chaincode to Channel"

	deployChaincode "$PEER_ORGS" 
}

# Export org identities used by the app
exportMSPs() {
	APP_DEST="${APP_PATH}"/identities
	mkdir -p "$APP_DEST"

	for org in $PEER_ORGS; do
		set -x
		cp -a "${FABRIC_HOME}"/organizations/peerOrganizations/"$org".domain.com/"$org"-users/users/admin0/. "$APP_DEST"/"$org"Registrar/
		set +x
	done
 	
 	set -x
	cp -a "${FABRIC_HOME}"/organizations/peerOrganizations/lynkeus.domain.com/users/blockclient/. "$APP_DEST"/blockClient/
	cp -a "${FABRIC_HOME}"/organizations/peerOrganizations/lynkeus.domain.com/peers/peer0.lynkeus.domain.com/. "$APP_DEST"/peer0Lynkeus/
	cp -a "${FABRIC_HOME}"/organizations/peerOrganizations/lynkeus.domain.com/users/prometheus .
	set +x
}

# Setup blockchain explorer and prometheus/grafana
setupMonitor() {
	printInfo "Setup Explorer and Prometheus"

	pushd blockchain-explorer || exit
	docker-compose up -d
	popd || exit

	createMetrics
	docker-compose -f ${DOCKER_HOME}/prometheus.yaml up -d

}

# Bring down the network
networkDown() {
	printHead "Bringing down the network"
	
	# Remove all fabric containers / volumes / images
	printInfo "Removing docker containers-images-volumes..."
	yes | docker container rm -vf $(docker ps -f network=${COMPOSE_PROJECT_NAME}_${STAGE} -f network=chaincode-docker-devmode_default -aq)
	yes | docker volume rm $(docker volume ls -f name=fabric* | awk '($2 ~ /fabric*/){print $2}')
	docker volume rm $(docker volume ls -qf dangling=true)
	removeUnwantedImages

	# Removing docker network
	docker network rm ${COMPOSE_PROJECT_NAME}_${STAGE}

	# Remove chaincode test network
	docker network rm chaincode-docker-devmode_default

	printInfo "Removing Org folders and artifacts..."
	rm -rf organizations
	rm -rf system-genesis-block
	rm -rf docker channel-artifacts
	rm ./log.txt *.block *.tar.gz

	# Clear explorer
	printInfo "Removing blockchain explorer"
	docker container rm -vf explorer.mynetwork.com explorerdb.mynetwork.com

	printInfo "Removing DB and App data"
	cleanApp

	# Init Chaincode Sequence and Version on configCC.sh
	sed -i -E "/^export CC_SEQUENCE/s/=.*$/=1/g" "${FABRIC_HOME}"/configCC.sh
	sed -i -E "/^export CC_VERSION/s/=.*$/=\"1.0\"/g" "${FABRIC_HOME}"/configCC.sh

	printSuccess "Network is down"
}

# Clean application data
cleanApp() {
	printInfo "Deleting DB and App folders"
	pushd ${APP_PATH} || exit
	./clean.sh
	popd || exit

}

# Delete any images that were generated as a part of this setup
# specifically the following images are often left behind:
# This function is called when you bring the network down
function removeUnwantedImages() {
  DOCKER_IMAGE_IDS=$(docker images | awk '($1 ~ /dev-peer.*/) {print $3}')
  if [ -z $DOCKER_IMAGE_IDS ] || [ $DOCKER_IMAGE_IDS == " " ]; then
    echo "---- No images available for deletion ----"
  else
    docker rmi -f $DOCKER_IMAGE_IDS
  fi
}

createNewOrg() {
	printInfo "Creating new organization Org3MSP"
	
	. scripts/addOrg.sh "org3"

	printSuccess "Org3 successfully created"
}

removeAllExceptCA() {
	printInfo "Removing all containers except CAs"

	# Remove peer containers
	docker container rm -vf $(docker ps --filter name="peer" -aq)
	
	# Remove orderer containers 
	docker container rm -vf $(docker ps --filter name="orderer.\." -aq)
	
	# Remove chaincode containers
	docker container rm -vf $(docker ps --filter name=dev. --filter status=exited -aq)
	
	# Remove dangling volumes
	docker volume rm $(docker volume ls -qf dangling=true)

	# Remove chaincode images
	removeUnwantedImages

	# Remove crypto files
	sudo rm -rf channel-artifacts/
	sudo rm -rf "$FABRIC_HOME"/organizations/peerOrganizations/*/peers
	sudo rm -rf "$FABRIC_HOME"/organizations/peerOrganizations/*/users
	sudo rm -rf "$FABRIC_HOME"/organizations/ordererOrganizations/*/orderers
	sudo rm -rf "$FABRIC_HOME"/organizations/ordererOrganizations/*/users
	docker container rm -vf explorer.mynetwork.com explorerdb.mynetwork.com

	# Remove users
	sudo rm -rf "$FABRIC_HOME"/organizations/peerOrganizations/*/*-users
	sudo rm -rf "$FABRIC_HOME"/organizations/peerOrganizations/*/usersmsp

	# Clean App
	cleanApp
	sed -i -E "/^export CC_SEQUENCE/s/=.*$/=1/g" "${FABRIC_HOME}"/configCC.sh
	sed -i -E "/^export CC_VERSION/s/=.*$/=\"1.0\"/g" "${FABRIC_HOME}"/configCC.sh

	# rm -rf grpc-comms/node_modules
	printSuccess "All containers deleted except CAs"
}


MODE=$1

if [ "${MODE}" == "step1" ]; then
	printHead "Step1: Create CAs"

	createOrgs
elif [ "${MODE}" == "step2" ]; then
	printHead "Step2: Create Orderers and Peers"

	createNodes
elif [ "${MODE}" == "step3" ]; then
	printHead "Step3: Create Genesis block and define consortium"

	createConsortium
elif [ "${MODE}" == "step4" ]; then
	printHead "Step4: Start the nodes"

	startNodes
elif [ "${MODE}" == "step5" ]; then
	printHead "Step5: Create and Join Channel"

	createChannel
elif [ "${MODE}" == "step6" ]; then
	printHead "Step6: Deploy Chaincode"

	deployCC
elif [ "${MODE}" == "step7" ]; then
	printHead "Step7: Exporting MSPs for the APP"

	exportMSPs
elif [ "${MODE}" == "metrics" ]; then
	printHead "Starting prometheus - grafana"

	createMetrics
	docker-compose -f docker/prometheus.yaml up -d
elif [ "${MODE}" == "addorg" ]; then
	printHead "Adding new Organization"

	createNewOrg 
fi 


if [ "${MODE}" == "up" ]; then
	networkUp
elif [ "${MODE}" == "down" ]; then	
	networkDown
elif [ "${MODE}" == "remake_certs" ]; then
	
	# Remove all first
	removeAllExceptCA

	# Remake
	createNodes	
	createConsortium
	startNodes
	createChannel
	deployCC
	exportMSPs
	sudo rm -rf channel-artifacts

	# pushd blockchain-explorer || exit
	# docker-compose up -d
	# popd
elif [ "${MODE}" == "start" ]; then
	printHead "Starting the network..."

	docker start $(docker ps -aq -f network=${COMPOSE_PROJECT_NAME}_${STAGE})

	printSuccess "All containers are up"
elif [ "${MODE}" == "stop" ]; then
	printHead "Stopping the network..."

	docker stop $(docker ps -aq -f network=${COMPOSE_PROJECT_NAME}_${STAGE})

	printSuccess "All containers are halted"
elif [ "${MODE}" == "rm" ]; then
	removeAllExceptCA
fi

if [ ! -z "$ERRORS" ]; then 
	printError "$ERRORS"
fi