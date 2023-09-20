#!/bin/bash
# Purpose: This script sets up and manages a Hyperledger Fabric Network.

# Directory setup.
[ ! -d logs ] && mkdir logs
[ ! -d ${CHANNEL_ARTIFACTS} ] && mkdir channel-artifacts

# Import required scripts.
. util.sh  # Utility functions for logging and error handling
. configGlobals.sh # User configuration on the network specifics
. configCC.sh # Chaincode configuration
. scripts/createChannel.sh
. scripts/deployCC.sh

### FUNCTIONS ###

# Create Organizations, Register and Enroll TLS,CA and Org Admins.
createOrgs() {
    printInfo "Setting up CAs - Org MSPs"

    if [ -d ${FABRIC_HOME}/organizations ]; then
        printError "Orgs exist. Exiting..."
        exit 0
    fi

    mkdir -p docker organizations/fabric-ca 

    # Setup for orderer organizations.
    for org in $ORDERER_ORGS; do
        setParams "$org"
        ./clientCA.sh setup_orgca -o "$org"
        ./clientCA.sh setup_orgmsp -o "$org" -t "orderer"
        ./clientCA.sh setup_orgops -o "$org"
    done

    # Setup for peer organizations.
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

		# Register admins
		./clientCA.sh register -t admin -u "$ADMIN_USER" -o "$org" -s "$ADMIN_USER_PW"
		./clientCA.sh enroll -t admin -u "$ADMIN_USER" -o "$org" -s "$ADMIN_USER_PW"
		./clientCA.sh register -t admin -u "$ORG_REGISTRAR" -o "$org" -s "$ORG_REGISTRAR_PW"
		./clientCA.sh enroll -t admin -u "$ORG_REGISTRAR" -o "$org" -s "$ORG_REGISTRAR_PW"

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

		# Register registar admins
		./clientCA.sh register -t admin -u "$ADMIN_USER" -o "$org" -s "$ADMIN_USER_PW"
		./clientCA.sh enroll -t admin -u "$ADMIN_USER" -o "$org" -s "$ADMIN_USER_PW"
		./clientCA.sh register -t admin -u "$ORG_REGISTRAR" -o "$org" -s "$ORG_REGISTRAR_PW"
		./clientCA.sh enroll -t admin -u "$ORG_REGISTRAR" -o "$org" -s "$ORG_REGISTRAR_PW"

		# Create Org-Users Admin which will be used to register users in the app as a registrar
		./clientCA.sh setup_orgusersca -o "$org" -t admin

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
	configtxgen -profile ${CHANNEL_PROFILE} -channelID ${CHANNEL_NAME} -outputBlock ./system-genesis-block/${CHANNEL_NAME}.block
	res=$?
	set +x

	verifyResult "$res" "Genesis block failed to generate" && printSuccess "Orderer genesis block generated!"
}

# Bring up the nodes
startNodes() {
	printInfo "Starting nodes"

	for org in $ORDERER_ORGS; do
		setPorts "$org"
		for orderer in $ORDERER_IDS; do
			set -x
			./peer.sh start -t orderer -n "$orderer"."$org".domain.com -p "${PORT_MAP[${orderer}]}"
			set +x
		done
	done

	local COUNT=0
	for org in $PEER_ORGS; do
		setPorts "$org"
		for peer in $PEER_IDS; do
			set -x
			./peer.sh start -t peer -n "$peer"."$org".domain.com -p "${PORT_MAP[${peer}]}" -D "${COUCHDB_PORTS[${COUNT}]}"
			set +x
			((COUNT++))
		done
	done

	printSuccess "Nodes are up and running!"
}

# Creates a new channel.
createChannel() {
    printInfo "Creating Channel ${CHANNEL_NAME}"

    createChannelA "$PEER_ORGS"
    res=$?
    verifyResult "$res" "network - createChannel - Channel creation failed!" && printSuccess "network - createChannel - Channel ${CHANNEL_NAME} Created!"
}

# Deploys chaincode to the specified channel.
deployCC() {
    printInfo "Deploy Chaincode to Channel"
    
    deployChaincode "$PEER_ORGS" 
}

# Export identities used by the app for authentication and authorization.
exportMSPs() {
    APP_DEST="${APP_PATH}"/identities
    mkdir -p "$APP_DEST"

    # Copying MSPs for Peer Orgs.
    for org in $PEER_ORGS; do
        cp -a "${FABRIC_HOME}"/organizations/peerOrganizations/"$org".domain.com/"$org"-users/users/${ADMIN_USER}/. "$APP_DEST"/"$org"UsersRegistrar/
        cp -a "${FABRIC_HOME}"/organizations/peerOrganizations/"$org".domain.com/users/registrar0/. "$APP_DEST"/"$org"Registrar/
    done

    # Copying specific organization data.
    cp -a "${FABRIC_HOME}"/organizations/peerOrganizations/agora.domain.com/users/blockclient/. "$APP_DEST"/blockClient/
    cp -a "${FABRIC_HOME}"/organizations/peerOrganizations/agora.domain.com/peers/peer0.agora.domain.com/. "$APP_DEST"/peer0agora/
    cp -a "${FABRIC_HOME}"/organizations/peerOrganizations/agora.domain.com/users/prometheus .
}

# Setup monitoring tools for the blockchain: Blockchain Explorer and Prometheus/Grafana.
setupMonitor() {
    printInfo "Setup Explorer and Prometheus"

    # Setting up Blockchain Explorer.
    pushd blockchain-explorer || exit
    docker-compose up -d
    popd || exit

    # Setting up Prometheus and Grafana.
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

# Creates a new organization.
# Currently set up for Org3MSP. Extendable for others.
createNewOrg() {
    printInfo "Creating new organization Org3MSP"
    
    # Source the organization addition script.
    . scripts/addOrg.sh "org3"
    
    printSuccess "Org3 successfully created"
}

# Removes all containers, volumes, and crypto files related to the network except CAs.
removeAllExceptCA() {
    printInfo "Removing all containers except CAs"

    # Remove Peer, Orderer and Chaincode Containers.
    docker container rm -vf $(docker ps --filter name="peer" -aq)
    docker container rm -vf $(docker ps --filter name="orderer.\." -aq)
    docker container rm -vf $(docker ps --filter name=dev. --filter status=exited -aq)
    
    # Remove Dangling Docker Volumes.
    docker volume rm $(docker volume ls -qf dangling=true)

    # Remove chaincode images.
    removeUnwantedImages

    # Remove crypto files.
    sudo rm -rf channel-artifacts/
    sudo rm -rf "$FABRIC_HOME"/organizations/peerOrganizations/*/peers
    sudo rm -rf "$FABRIC_HOME"/organizations/peerOrganizations/*/users
    sudo rm -rf "$FABRIC_HOME"/organizations/ordererOrganizations/*/orderers
    sudo rm -rf "$FABRIC_HOME"/organizations/ordererOrganizations/*/users
    docker container rm -vf explorer.mynetwork.com explorerdb.mynetwork.com

    # Remove user data.
    sudo rm -rf "$FABRIC_HOME"/organizations/peerOrganizations/*/*-users
    sudo rm -rf "$FABRIC_HOME"/organizations/peerOrganizations/*/usersmsp

    # Clean up application data and reset config.
    cleanApp
    sed -i -E "/^export CC_SEQUENCE/s/=.*$/=1/g" "${FABRIC_HOME}"/configCC.sh
    sed -i -E "/^export CC_VERSION/s/=.*$/=\"1.0\"/g" "${FABRIC_HOME}"/configCC.sh
    
    printSuccess "All containers deleted except CAs"
}


# Start the network
networkUp() {
	printHead "Bringing up the network"

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


if [ "$1" == "--help" ] || [ "$1" == "-h" ] || [ -z "$1" ]; then
    echo "Usage: $0 <mode>"
    echo
    echo "Available modes:"
    echo "  step1            - Step1: Create CAs"
    echo "  step2            - Step2: Create Orderers and Peers"
    echo "  step3            - Step3: Create Genesis block and define consortium"
    echo "  step4            - Step4: Start the nodes"
    echo "  step5            - Step5: Create and Join Channel"
    echo "  step6            - Step6: Deploy Chaincode"
    echo "  step7            - Step7: Exporting MSPs for the APP"
    echo "  metrics          - Starting prometheus - grafana"
    echo "  addorg           - Adding new Organization"
    echo "  up               - Start the network"
    echo "  down             - Bring the network down"
    echo "  remake_certs     - Bring the network down except CAs and recreate them"
    echo "  start            - Start the halted network"
    echo "  stop             - Halt the running network"
    echo "  rm               - Remove all configurations"
    echo
    echo "Help options:"
    echo "  --help or -h     - Show this help menu"
    exit 0
fi


MODE=$1

# Depending on the mode, perform the corresponding task.
case "$MODE" in
    "step1")
        printHead "Step1: Create CAs"
        createOrgs
        ;;
    "step2")
        printHead "Step2: Create Orderers and Peers"
        createNodes
        ;;
    "step3")
        printHead "Step3: Create Genesis block and define consortium"
        createConsortium
        ;;
    "step4")
        printHead "Step4: Start the nodes"
        startNodes
        ;;
    "step5")
        printHead "Step5: Create and Join Channel"
        createChannel
        ;;
    "step6")
        printHead "Step6: Deploy Chaincode"
        deployCC
        ;;
    "step7")
        printHead "Step7: Exporting MSPs for the APP"
        exportMSPs
        ;;
    "metrics")
        printHead "Starting prometheus - grafana"
        createMetrics
        docker-compose -f docker/prometheus.yaml up -d
        ;;
    "addorg")
        printHead "Adding new Organization"
        createNewOrg 
        ;;
    "up")
        networkUp
        ;;
    "down")
        networkDown
        ;;
    "remake_certs")
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
        ;;
    "start")
        printHead "Starting the network..."
        docker start $(docker ps -aq -f network=${COMPOSE_PROJECT_NAME}_${STAGE})
        printSuccess "All containers are up"
        ;;
    "stop")
        printHead "Stopping the network..."
        docker stop $(docker ps -aq -f network=${COMPOSE_PROJECT_NAME}_${STAGE})
        printSuccess "All containers are halted"
        ;;
    "rm")
        removeAllExceptCA
        ;;
    *)
        printError "Unknown mode: $MODE"
        exit 1
        ;;
esac

# Check and print errors, if any.
if [ ! -z "$ERRORS" ]; then 
    printError "$ERRORS"
fi