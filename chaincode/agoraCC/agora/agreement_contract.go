package agora

/* Import required libs */
import (
	"encoding/json"
	"fmt"
	"log"

	"github.com/hyperledger/fabric-chaincode-go/pkg/cid"
	// "github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// IsEligible checks if a buyer is eligible to buy a product by comparing
// buyer's parameters with product's data policy
// It returns a boolean indicating the eligibility and an error, if any.
func (s *AgreementContract) IsEligible(ctx TransactionContextInterface, product *Product, buyerParams BuyerParams) (bool, error) {
	err := s.validatePolicy(ctx, buyerParams, product)
	if err != nil {
		return false, err
	}
	return true, nil
}

// validatePolicy Matches policy of buyer and product
func (s *AgreementContract) validatePolicy(ctx TransactionContextInterface, buyerParams BuyerParams, product *Product) error {
	method := "validatePolicy"
	log.Printf("%s - start\n", method)

	log.Printf("%s - Buyer's purposes: %s\n", method, buyerParams.Purposes)
	log.Printf("%s - Policy purpose: %s\n", method, product.Policy.Purposes)

	buyer := ctx.GetData()

	// TODO
	// CHECK IF ORG IS VERIFIED
	// verified = true/false

	// seller, err := userContract.ReadUser(ctx, product.Owner)
	// if err != nil {
	// 	return fmt.Errorf("%s: %s", method, err)
	// }
	// log.Printf("%+v", seller)

	// Check for data access level
	if len(product.DataAccessLevels) > 0 {
		var levels []string
		for _, dal := range product.DataAccessLevels {
			levels = append(levels, dal.Level)
		}
		if !_in(buyerParams.DataAccessLevel, levels) {
			return fmt.Errorf("%s: Data Access Level %s does not exist in the product.", method, buyerParams.DataAccessLevel)
		}
	}

	// If User is PreApproved, make no other checks
	if _in(buyer.ID, product.Policy.ApprovedUsers) {
		return nil
	}

	// Check if buyer is a verified member of org
	userOrg, err := assertCallerBelongsToOrg(ctx)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	// Check if org is inactive
	if !userOrg.Org.Active {
		return fmt.Errorf("%s: Organization is not active", method)
	}

	// Differentiate sector
	if product.Sector == HEALTH {

		// Analytics
		if product.ProductType == ANALYTICS {

			// Check Institution
			err = s.checkInstitutionType(userOrg.Org.InstType, product.Policy.RecipientType)
			if err != nil {
				return fmt.Errorf("%s: %v", method, err)
			}
		}

		// Batch, Streams
		if product.ProductType != ANALYTICS {

			// Check if Org is Pre-Approved on this specific Data Product
			if !_in(buyer.IsMemberOf, product.Policy.ApprovedOrgs[:]) {
				return fmt.Errorf("%s: Buyer's Org is not pre approved on this data product.", method)
			}

			// Check Purposes
			err = s.checkPurposes(buyerParams.Purposes, product.Policy.Purposes)
			if err != nil {
				return fmt.Errorf("%s: %v", method, err)
			}
		}
	}

	if product.Sector == EDUCATION {

		// Check Institution
		if err := s.checkInstitutionType(userOrg.Org.InstType, product.Policy.RecipientType); err != nil {
			return fmt.Errorf("%s: %v", method, err)
		}

		// Batch, Streams
		if product.ProductType != ANALYTICS {
			if err := s.checkPurposes(buyerParams.Purposes, product.Policy.Purposes); err != nil {
				return fmt.Errorf("%s: %v", method, err)
			}
		}
	}

	log.Printf("%s - end\n", method)
	return nil
}

// checkInstitutionType Match policy on institution types
func (s *AgreementContract) checkInstitutionType(buyerInst string, policyInst []string) error {
	method := "checkInstitutionType"

	// Check Institution Types
	if !_in(buyerInst, policyInst) {
		return fmt.Errorf("%s: Buyer's org institution type is not compatible with data policy", method)
	}

	return nil
}

// checkPurposes Match policy on purposes of buying
func (s *AgreementContract) checkPurposes(buyerPurposes []string, policyPurposes []string) error {
	method := "checkPurposes"

	// Check Purposes
	err := validateValues(buyerPurposes, policyPurposes)
	if err != nil {
		return fmt.Errorf("%s: Purposes of buying not compatible with policy", method)
	}

	if len(buyerPurposes) > len(policyPurposes) {
		return fmt.Errorf("%s: Too many purposes of buying. Not compatible with policy", method)
	}

	return nil

}

// newAgreement Create a new transaction between buyer and product
func (s *AgreementContract) newAgreement(ctx TransactionContextInterface, product Product) (string, error) {
	method := "newAgreement"
	log.Printf("%s - start\n", method)

	transactionID := ctx.GetStub().GetTxID()

	var agreement Agreement
	agreement.ObjectType = AGREEMENT_OBJECT_TYPE
	agreement.Buyer = ctx.GetData().Username
	agreement.Seller = product.Owner
	agreement.ProductID = product.ID
	agreement.ProductType = product.ProductType
	agreement.Price = product.Price
	agreement.Status = "Eligible"
	agreement.TransactionID = transactionID

	// Timestamp in Unix Nanoseconds
	timestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s - Error getting timestamp", method)
	}

	agreement.Timestamp = timestamp.Seconds
	log.Printf("%s - %+v", method, agreement)

	agreementBytes, err := json.Marshal(agreement)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	key, _ := ctx.GetStub().CreateCompositeKey(AGREEMENT_OBJECT_TYPE, []string{transactionID})

	/* Put User Inventory STATE */
	err = ctx.GetStub().PutState(key, agreementBytes)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	/* End */
	if agreement.ProductType == ANALYTICS {
		ctx.GetStub().SetEvent("NewAgreementAnalytics", agreementBytes)
	} else {
		ctx.GetStub().SetEvent("NewAgreement", agreementBytes)
	}

	log.Printf("%s - end\n", method)
	return transactionID, nil
}

// UpdateAgreement Update agreement status
func (s *AgreementContract) UpdateAgreement(ctx TransactionContextInterface, txID string, status string) error {
	method := "UpdateAgreement"
	log.Printf("%s - start\n", method)

	// Check if caller belongs to the Organization as a non User
	// Should be non User MSP
	mspID, err := ctx.GetClientIdentity().GetMSPID()
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	if !isAuthorizedMSP(mspID) {
		return fmt.Errorf("%s - Not authorized to change agreement state", method)
	}

	// TODO: ADMIN ROLE MAYBE?
	// Check if caller is a client
	hasOuValue, err := cid.HasOUValue(ctx.GetStub(), CLIENT)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	if !hasOuValue {
		return fmt.Errorf("%s - OU value is not %s", method, CLIENT)
	}

	// Check if input status has correct value
	if !_in(status, AGREEMENT_STATUS) {
		return fmt.Errorf("%s - Wrong value for status", method)
	}

	key, _ := ctx.GetStub().CreateCompositeKey(AGREEMENT_OBJECT_TYPE, []string{txID})
	agreementBytes, err := ctx.GetStub().GetState(key)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	if agreementBytes == nil {
		return fmt.Errorf("%s - agreement %s does not exist", method, txID)
	}

	var agreement *Agreement
	err = json.Unmarshal(agreementBytes, &agreement)
	agreement.Status = status

	agreementBytes, err = json.Marshal(agreement)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	err = ctx.GetStub().PutState(key, agreementBytes)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	ctx.GetStub().SetEvent("UpdateAgreement", agreementBytes)

	log.Printf("%s - end\n", method)
	return nil
}

// GetAgreement Query an agreement by ID
func (s *AgreementContract) GetAgreement(ctx TransactionContextInterface, transactionID string) (*Agreement, error) {
	method := "GetAgreement"

	key, _ := ctx.GetStub().CreateCompositeKey(AGREEMENT_OBJECT_TYPE, []string{transactionID})
	agreementBytes, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	if agreementBytes == nil {
		return nil, fmt.Errorf("%s: Agreement %s does not exist", method, transactionID)
	}

	var agreement *Agreement
	err = json.Unmarshal(agreementBytes, &agreement)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return agreement, nil
}

// GetAgreements Query all agreements
func (s *AgreementContract) GetAgreements(ctx TransactionContextInterface) ([]*Agreement, error) {
	method := "GetAgreements"

	resultsIterator, err := ctx.GetStub().GetStateByPartialCompositeKey(AGREEMENT_OBJECT_TYPE, nil)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer resultsIterator.Close()

	var agreements []*Agreement
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		var agreement *Agreement
		err = json.Unmarshal(queryResponse.Value, &agreement)
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}
		agreements = append(agreements, agreement)
	}

	return agreements, nil
}

func (s *AgreementContract) GetClass() string {
	var _ = fmt.Printf
	var _ = json.Marshal
	return AGREEMENT_OBJECT_TYPE
}
