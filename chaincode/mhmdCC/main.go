package main

import (
	mhmd "github.com/alxspectrum/chaincode/mhmdCC/mhmd"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"log"
	// "os"
)

func main() {
	log.Print("Starting mhmd...")

	// Sets Date Time File on logs
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Handle User Contract
	userSC := new(mhmd.UserContract)
	userSC.TransactionContextHandler = new(mhmd.TransactionContext)
	userSC.BeforeTransaction = mhmd.BeforeTransaction

	// Handle Product Contract
	productSC := new(mhmd.DataContract)
	productSC.TransactionContextHandler = new(mhmd.TransactionContext)
	productSC.BeforeTransaction = mhmd.BeforeTransaction

	// Handle Agreement Contract
	agreementSC := new(mhmd.AgreementContract)
	agreementSC.TransactionContextHandler = new(mhmd.TransactionContext)
	agreementSC.BeforeTransaction = mhmd.BeforeTransaction

	// Handle Management Contract
	managementSC := new(mhmd.ManagementContract)
	managementSC.TransactionContextHandler = new(mhmd.TransactionContext)
	managementSC.BeforeTransaction = mhmd.BeforeTransaction

	// Assemble Chaincode
	mhmdCC, err := contractapi.NewChaincode(userSC, productSC, agreementSC, managementSC)

	// Start Chaincode
	if err != nil {
		log.Panicf("Error creating chaincode %v", err)
	}
	if err := mhmdCC.Start(); err != nil {
		log.Panicf("Error starting chaincode %v", err)
	}

}
