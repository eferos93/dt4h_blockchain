package dt4h

import (
	"fmt"
	"log"
	"slices"
)

// BeforeTransaction is the hook executed before every chaincode function.
// It extracts the caller's identity from the client certificate and stores
// it in the transaction context so that contract methods can access it.
func BeforeTransaction(ctx TransactionContextInterface) error {
	method := "BeforeTransaction"

	userID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return fmt.Errorf("%s: failed to get user ID: %v", method, err)
	}

	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("%s: failed to get MSP ID: %v", method, err)
	}

	ctx.SetUserID(userID)
	ctx.SetMspID(mspID)

	log.Printf("%s: caller=%s  msp=%s", method, userID, mspID)
	return nil
}

// assertAuthorizedMSP rejects callers whose MSP is not in the allow-list.
func assertAuthorizedMSP(ctx TransactionContextInterface) error {
	msp := ctx.GetMspID()
	if slices.Contains(AUTHORIZED_MSPS, msp) {
		return nil
	}
	return fmt.Errorf("unauthorized MSP: %s", msp)
}
