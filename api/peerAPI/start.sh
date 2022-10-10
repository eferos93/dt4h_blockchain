#!/bin/bash

# Start peer docker container
startPeer() {
	DOCK_COMPOSE_COUCH=${DOCKER_HOME}/docker-couchDB-${NODE_ID}-${ORG_NAME}.yaml

	# Create CouchDB Docker-Compose file 
	createDockerCouchDB "${ORG_NAME}" "${NODE_ID}" "${DB_PORT}"

	# Create Peer Docker-Compose file
	createDockerPeer "${ORG_NAME}" "${NODE_ID}" "${NODE_PORT}"
	
	# Start Peer
	docker-compose -f "${DOCK_COMPOSE_FILE}" -f "$DOCK_COMPOSE_COUCH" up -d 2>&1
	sleep 3
}

# Start orderer docker container
startOrderer() {
	# Create docker compose file for orderer
	createDockerOrderer "${ORG_NAME}" "${NODE_ID}" "${NODE_PORT}"
	
	# Start the orderer
	docker-compose -f "${DOCK_COMPOSE_FILE}" up -d 2>&1
	sleep 3
}

startNode() {
	if [[ -z "${ORG_NAME}" ]]; then
		printError "startNode - Missing organization name."
		exit 1
	fi

	if [[ -z "${NODE_PORT}" ]]; then
		printError "startNode - Missing node port."
		exit 1
	fi
	
	if [[ -z ${NODE_ID} ]]; then
		printError "startNode - Missing Node ID."
		exit 1
	fi
	
	if [ ! -f ${FABRIC_CFG_PATH}/${NODE_ID}-${ORG_NAME}.yaml ]; then
		printWarn "startNode - Missing Node configuration: ${NODE_ID}-${ORG_NAME}.yaml"
		return
	fi

	[ ! -d ${DOCKER_HOME} ] && mkdir -p ${DOCKER_HOME}
	DOCK_COMPOSE_FILE=${DOCKER_HOME}/docker-compose-"${NODE_ID}"-${ORG_NAME}.yaml

	if [[ "${TYPE}" == "peer" ]]; then
		startPeer
	elif [[ "${TYPE}" == "orderer" ]]; then
		startOrderer
	else
		printError "startNode - Type: ${TYPE} not found"
		exit 1
	fi
}