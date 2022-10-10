#!/bin/bash

# Package chaincode

packageCC() {
  printInfo "packageCC - Packaging chaincode ${CC_NAME}_${CC_VERSION}"

  set -x
  peer lifecycle chaincode package ${CC_NAME}.tar.gz -p ${CC_PATH} --label ${CC_NAME}_${CC_VERSION} >& log.txt
  res=$?
  set +x

  verifyResult "$res" "$(cat log.txt)" && printSuccess "Chaincode is packaged as ${CC_NAME}.tar.gz"
}

# packageCC 