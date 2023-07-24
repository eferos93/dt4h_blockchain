#!/bin/bash

. configGlobals.sh
. util.sh

# Use REUSE_KEY flag to keep private key and just update expiration date
REUSE_KEY="--reuse-key"
# CA_TYPE=ca
CA_TYPE=tls
set -e

# printWarn "Configure values before me and then comment me" && exit 1

for org in $ORDERER_ORGS; do
	setParams "$org"
	for orderer in $ORDERER_IDS; do
		./clientCA.sh reenroll -t orderer -u "$orderer" -o "$org" -s "$ordererpw" --catype ${CA_TYPE} ${REUSE_KEY}
	done

	./clientCA.sh reenroll -t admin -u "$admin" -o "$org" -s "$adminpw" --catype ${CA_TYPE} ${REUSE_KEY}

done

for org in $PEER_ORGS; do
	setParams "$org"
	for peer in $PEER_IDS; do
		./clientCA.sh reenroll -t peer -u "$peer" -o "$org" -s "$peerpw" --catype ${CA_TYPE} ${REUSE_KEY}
	done

	./clientCA.sh reenroll -t admin -u "$admin" -o "$org" -s "$adminpw" --catype ${CA_TYPE} ${REUSE_KEY}
done

chmod -R 755 ${FABRIC_HOME}/organizations
