#!/bin/bash

# Fetch and decode channel configuration block

fetchChannelConfig() {
	OUTPUT=config.json
	printInfo "fetchChannelConfig - Fetching the most recent channel ${CHANNEL_NAME} configuration..."

	mkdir -p ${CHANNEL_ARTIFACTS} && pushd ${CHANNEL_ARTIFACTS} >/dev/null || exit 

	set -x
	peer channel fetch config config_block.pb -c ${CHANNEL_NAME} -o ${ORDERER}  --tls --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} --cafile ${ORDERER_CAFILE} ${TLSHANDSHAKETIMESHIFT}
	res=$?
	set +x
	verifyResult "$res" "fetchChannelConfig - Failed to fetch config for ${CHANNEL_NAME}" || exit 1

	printInfo "fetchChannelConfig - Decoding config block to JSON and isolate config to ${OUTPUT}"
	set -x
	configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > "${OUTPUT}"
	res=$?
	set +x

	popd
	verifyResult "$res" "fetchChannelConfig - Failed to decode config for ${CHANNEL_NAME}" && printSuccess "fetchChannelConfig - Channel config as JSON at ${OUTPUT}"
}

# fetchChannelConfig