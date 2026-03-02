package dt4h

import (
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// TransactionContextInterface extends the base Fabric context with
// caller-identity accessors populated by BeforeTransaction.
type TransactionContextInterface interface {
	contractapi.TransactionContextInterface

	// GetUserID returns the X.509 subject identifier of the caller.
	GetUserID() string
	SetUserID(string)

	// GetMspID returns the MSP identifier of the caller's organization.
	GetMspID() string
	SetMspID(string)
}

// TransactionContext is the concrete implementation wired into every contract.
type TransactionContext struct {
	contractapi.TransactionContext
	userID string
	mspID  string
}

func (tc *TransactionContext) GetUserID() string  { return tc.userID }
func (tc *TransactionContext) SetUserID(id string) { tc.userID = id }
func (tc *TransactionContext) GetMspID() string    { return tc.mspID }
func (tc *TransactionContext) SetMspID(id string)  { tc.mspID = id }
