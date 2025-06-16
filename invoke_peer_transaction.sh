# invoke a peer transaction script

# Code: app.js validate <peer> <channel> <chaincode> <function> <args>

# Usage: ${FABRIC_HOME}/invoke_peer_transaction.sh

# Set the environment variables for the peer

export CORE_PEER_TLS_ENABLED=true

export CORE_PEER_LOCALMSPID="Bsc1MSP"
export FABRIC_HOME=${PWD}

export PEER_HOME=${FABRIC_HOME}/organizations/peerOrganizations/bsc.dt4h.com/peers/peer0.bsc.dt4h.com
export CORE_PEER_TLS_ROOTCERT_FILE=${PEER_HOME}/tls/tlscacerts/ca.crt

# Check if the TLS certificate file exists
if [ ! -f "$CORE_PEER_TLS_ROOTCERT_FILE" ]; then
  echo "Error: TLS certificate file not found at $CORE_PEER_TLS_ROOTCERT_FILE"
  exit 1
fi

# invoke the transaction using the typescript application
# just one input "validate". Find where the rest can be reached.

node application-typescript/app.js validate peer0.athena.com agora myCC management_contract isAuthorizedMSP '{"mspId":"Org1MSP"}'
