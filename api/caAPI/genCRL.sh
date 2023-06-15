#!/bin/bash

# Generate Certificate Revocation List
function gencrl() {
	printInfo "gencrl - Generating crl for ${ORG_NAME} CA name ${CA_NAME}"

	set -x
	fabric-ca-client gencrl --revokedafter 2017-09-13T16:39:57-08:00 -u https://"$caendpoint" --caname "$CA_NAME" -M "$CAMSPDIR" --tls.certfiles "$TLS_ROOTCERT_PATH"
	res=$?
	set +x
	verifyResult "$res" "gencrl - Failed to generate CRL for $ORG_NAME"

	printSuccess "gencrl - ${ORG_NAME} ${CA_NAME} CRL Generated!"
}