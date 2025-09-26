#!/bin/bash


# Bring up the CA Server
# Starting the server reconfigures the csr parameters from the imported
# fabric-ca-server-config.yaml file, thus it should be called
# before the creation of the client because the certificates
# will be deleted and no longer be valid
startServer() {
	printInfo "startServer - Starting ${ORG_NAME} Server..."
	
	if [ -z "$DOCK_COMPOSE_FILE" ]; then
		[ -z "$CA_TYPE" ] && printError "Missing ca type (-c)" && exit 1
		[ -z "$ORG_NAME" ] && printError "Missing org name (-o)" && exit 1
		export DOCK_COMPOSE_FILE=${DOCKER_HOME}/docker-compose-${CA_TYPE}-${ORG_NAME}.yaml
	fi

	docker-compose -f "$DOCK_COMPOSE_FILE" up -d 2>&1
	sleep 3
}	
