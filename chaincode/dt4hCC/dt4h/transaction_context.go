package dt4h

import (
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type TransactionContextInterface interface {
	contractapi.TransactionContextInterface
	// GetData() User
	// SetData(User)
	GetData() string
	SetData(string)
}

type TransactionContext struct {
	contractapi.TransactionContext
	// data User
	data string
}

func (tc *TransactionContext) GetData() string {
	return tc.data
}

func (tc *TransactionContext) SetData(data string) {
	tc.data = data
}
