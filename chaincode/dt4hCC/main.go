package main

import (
	"log"

	dt4h "github.com/chaincode/dt4hCC/dt4h"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	// "os"
)

func main() {
	log.Print("Starting dt4h...")

	// Sets Date Time File on logs
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Handle User Contract
	// userSC := new(dt4h.UserContract)
	// userSC.TransactionContextHandler = new(dt4h.TransactionContext)
	// userSC.BeforeTransaction = dt4h.BeforeTransaction

	// Handle Product Contract
	// productSC := new(dt4h.DataContract)
	// productSC.TransactionContextHandler = new(dt4h.TransactionContext)
	// productSC.BeforeTransaction = dt4h.BeforeTransaction

	// // Handle Agreement Contract
	// agreementSC := new(dt4h.AgreementContract)
	// agreementSC.TransactionContextHandler = new(dt4h.TransactionContext)
	// agreementSC.BeforeTransaction = dt4h.BeforeTransaction

	// // Handle Management Contract
	// managementSC := new(dt4h.ManagementContract)
	// managementSC.TransactionContextHandler = new(dt4h.TransactionContext)
	// managementSC.BeforeTransaction = dt4h.BeforeTransaction

	querySC := new(dt4h.QueryContract)
	querySC.TransactionContextHandler = new(dt4h.TransactionContext)
	querySC.BeforeTransaction = dt4h.BeforeTransaction

	// Assemble Chaincode
	dt4hCC, err := contractapi.NewChaincode(querySC)

	// Start Chaincode
	if err != nil {
		log.Panicf("Error creating chaincode %v", err)
	}
	if err := dt4hCC.Start(); err != nil {
		log.Panicf("Error starting chaincode %v", err)
	}

}
