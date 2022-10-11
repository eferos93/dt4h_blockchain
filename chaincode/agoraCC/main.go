package main

import (
	agora "github.com/alxspectrum/chaincode/agoraCC/agora"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"log"
	// "os"
)

func main() {
	log.Print("Starting agora...")

	// Sets Date Time File on logs
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Handle User Contract
	userSC := new(agora.UserContract)
	userSC.TransactionContextHandler = new(agora.TransactionContext)
	userSC.BeforeTransaction = agora.BeforeTransaction

	// Handle Product Contract
	productSC := new(agora.DataContract)
	productSC.TransactionContextHandler = new(agora.TransactionContext)
	productSC.BeforeTransaction = agora.BeforeTransaction

	// Handle Agreement Contract
	agreementSC := new(agora.AgreementContract)
	agreementSC.TransactionContextHandler = new(agora.TransactionContext)
	agreementSC.BeforeTransaction = agora.BeforeTransaction

	// Handle Management Contract
	managementSC := new(agora.ManagementContract)
	managementSC.TransactionContextHandler = new(agora.TransactionContext)
	managementSC.BeforeTransaction = agora.BeforeTransaction

	// Assemble Chaincode
	agoraCC, err := contractapi.NewChaincode(userSC, productSC, agreementSC, managementSC)

	// Start Chaincode
	if err != nil {
		log.Panicf("Error creating chaincode %v", err)
	}
	if err := agoraCC.Start(); err != nil {
		log.Panicf("Error starting chaincode %v", err)
	}

}
