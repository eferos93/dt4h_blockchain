#!/bin/bash

. configGlobals.sh
. util.sh

######### 				  		######### 
######### 	RENEW CERTS ONCE 	######### 
######### 				  		#########


### THIS CREATES A NEW KEYPAIR FOR THE ORG ADMIN WHICH IS RARELY USED
### FROM THE ORG ADMIN, THE CHANNEL USES CACERTS AND TLSCACERTS
### WHICH ARE THE ROOT CA CERTIFICATES FOR ID AND TLS 
### WE DO NOT USE THIS ADMIN TO SIGN OPERATIONS, WE ENROLL ANOTHER ADMIN
### FOR THE PURPOSE OF ADMIN OPERATIONS
org=orgexample
type=peer
./clientCA.sh enrollorgadmin -o "${org}" -t "${type}" --catype ca

chmod -R 755 ${FABRIC_HOME}/organizations
