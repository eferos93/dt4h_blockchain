#!/bin/bash


##########################
# List Identities associated with the specified organization.
# Globals:
#   ORG_NAME, TLS, TLS_ENDPOINT, CA_ENDPOINT, TLS_ADMIN, USERS, 
#   USERSCA_ADMIN, CA_NAME, CA_ADMIN
# Arguments:
#   None
# Returns:
#   None
##########################
identityList() {
    printInfo "identityList - Listing Identities of ${ORG_NAME}"

    # Check if ORG_NAME is specified
    if [ -z "${ORG_NAME}" ]; then
        printError "identityList - No org specified"
        exit 1
    fi

    # Handle case for TLS
    if [ $TLS ]; then
        set -x
        fabric-ca-client identity list --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${TLS_ENDPOINT} -M ./tls-ca/${TLS_ADMIN}/msp
        res=$?
        set +x
        verifyResult "$res" "identityList - Failed to get identities"
    else    
        # Handle user's specific request
        if [[ $USERS ]]; then
            set -x
            fabric-ca-client identity list --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${CA_ENDPOINT} -M ./${ORG_NAME}-users-ca/${USERSCA_ADMIN}/msp/ --caname ${CA_NAME}
            res=$?
            set +x
        else 
            set -x
            fabric-ca-client identity list --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${CA_ENDPOINT} -M ./${ORG_NAME}-ca/${CA_ADMIN}/msp/
            res=$?
            set +x
        fi
        verifyResult "$res" "identityList - Failed to get identities"
    fi
}

##########################
# Modify identity attributes associated with the specified organization.
# Globals:
#   ORG_NAME, TLS, TLS_ENDPOINT, CA_ENDPOINT, USERNAME, TLS_ADMIN, 
#   USERS, USERSCA_ADMIN, CA_NAME, CA_ADMIN
# Arguments:
#   None
# Returns:
#   None
##########################
identityModify() {
    printInfo "identityModify - Modifying identity of ${ORG_NAME}"

    # Check if ORG_NAME is specified
    if [ -z "${ORG_NAME}" ]; then
        printError "identityModify - No org specified"
        exit 1
    fi

    # Handle case for TLS
    if [ $TLS ]; then
        set -x
        fabric-ca-client identity modify ${USERNAME}  --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${TLS_ENDPOINT} -M ./tls-ca/${TLS_ADMIN}/msp
        res=$?
        set +x
        verifyResult "$res" "identityModify - Failed to get identities"
    else    
        # Handle user's specific request
        if [[ $USERS ]]; then
            set -x
            fabric-ca-client identity modify  ${USERNAME} --id.attrs hf.Registrar.Roles=*  --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${CA_ENDPOINT} -M ./${ORG_NAME}-users-ca/${USERSCA_ADMIN}/msp/ --caname ${CA_NAME}
            res=$?
            set +x
        else 
            set -x
            fabric-ca-client identity modify  ${USERNAME} --tls.certfiles ./tls-root-cert/tls-ca-cert.pem -u https://${CA_ENDPOINT} -M ./${ORG_NAME}-ca/${CA_ADMIN}/msp/
            res=$?
            set +x
        fi
        verifyResult "$res" "identityModify - Failed to get identities"
    fi
}
