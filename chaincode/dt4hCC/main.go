package main

import (
	"log"

	dt4h "github.com/chaincode/dt4hCC/dt4h"
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

func main() {
	log.Print("Starting dt4h...")
	log.SetFlags(log.LstdFlags | log.Lshortfile)

	// Query Contract – query logging + user history
	querySC := new(dt4h.QueryContract)
	querySC.TransactionContextHandler = new(dt4h.TransactionContext)
	querySC.BeforeTransaction = dt4h.BeforeTransaction

	// Privacy Budget Contract – DP epsilon budget management
	budgetSC := new(dt4h.PrivacyBudgetContract)
	budgetSC.TransactionContextHandler = new(dt4h.TransactionContext)
	budgetSC.BeforeTransaction = dt4h.BeforeTransaction

	// Assemble Chaincode
	dt4hCC, err := contractapi.NewChaincode(querySC, budgetSC)
	if err != nil {
		log.Panicf("Error creating chaincode: %v", err)
	}

	// Start Chaincode
	if err := dt4hCC.Start(); err != nil {
		log.Panicf("Error starting chaincode: %v", err)
	}
}
