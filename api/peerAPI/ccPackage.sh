#!/bin/bash

# -----------------------------------------------------------------------------
# Copyright Agora Labs. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
# -----------------------------------------------------------------------------

# Description: This script contains a function to package 
#              a Hyperledger Fabric chaincode.

packageCC() {
  
  # Print informational message about the chaincode being packaged
  printInfo "packageCC - Packaging chaincode ${CC_NAME}_${CC_VERSION}"

  # Execute the command to package the chaincode and redirect output to log
  set -x
  peer lifecycle chaincode package ${CC_NAME}.tar.gz -p ${CC_PATH} --label ${CC_NAME}_${CC_VERSION} >& log.txt
  res=$?
  set +x

  verifyResult "$res" "$(cat log.txt)" && printSuccess "Chaincode is packaged as ${CC_NAME}.tar.gz"
}
