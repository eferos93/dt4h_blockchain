package dt4h

import (
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

type TransactionContextInterface interface {
	contractapi.TransactionContextInterface
	GetData() User
	SetData(User)
}

type TransactionContext struct {
	contractapi.TransactionContext
	data User
}

func (tc *TransactionContext) GetData() User {
	return tc.data
}

func (tc *TransactionContext) SetData(data User) {
	tc.data = data
}
