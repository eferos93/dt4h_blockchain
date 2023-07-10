#!/bin/bash

osnChannelJoin() {
    printInfo "joinChannel - Joining osn orderer ${NODE_ID}.${ORG_NAME} to channel ${CHANNEL_NAME}..."

    local rc=1
    local COUNTER=1
    MAX_RETRY=3
    # Join channel	
    while [ $rc -ne 0 -a $COUNTER -ne $MAX_RETRY ]; do
        set -x 
	    osnadmin channel join --channelID $CHANNEL_NAME --config-block ./system-genesis-block/${CHANNEL_NAME}.block -o localhost:${NODE_PORT} --ca-file "$ORDERER_CAFILE" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" >&log.txt
	    # osnadmin channel list --channelID $CHANNEL_NAME -o localhost:${NODE_PORT} --ca-file "$ORDERER_CAFILE" --client-cert "$ORDERER_ADMIN_TLS_SIGN_CERT" --client-key "$ORDERER_ADMIN_TLS_PRIVATE_KEY" >&log.txt
        res=$?
        set +x
        rc=$res
        sleep 2
        COUNTER=$(expr $COUNTER + 1)	
    done

    verifyResult "$res" "$(cat log.txt)" && printSuccess "joinChannel - Orderer ${NODE_ID}.${ORG_NAME} joined channel ${CHANNEL_NAME}"   
}

export -f osnChannelJoin