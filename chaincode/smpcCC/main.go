package main

import (
	"log"

	smpc "github.com/alxspectrum/chaincode/smpcCC/smpc"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"

)

func main() {
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	log.Println("Starting chaincode mpcsc...")

	requestRouterSC := new(smpc.RequestRouter)

	smpcCC, err := contractapi.NewChaincode(requestRouterSC)
	
	// Start Chaincode
	if err != nil {
		log.Panicf("Error creating chaincode %v", err)
	}
	if err := smpcCC.Start(); err != nil {
		log.Panicf("Error starting chaincode %v", err)
	}	
}