package agora

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"strconv"
	"time"
	// "bytes"
)

// CreateProduct Create a product
func (s *DataContract) CreateProduct(ctx TransactionContextInterface, productStr string) (string, error) {
	method := "CreateProduct"
	log.Printf("%s:  start\n", method)

	product, err := s.getProdFromString(productStr)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	// Validate parameters
	if err = s.validateCUD(ctx, product, 0); err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	product.Owner = ctx.GetData().Username
	product.ObjectType = PRODUCT_OBJECT_TYPE

	/* Assign ID to product */
	ID, err := s.createProductID(ctx, product.Owner)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	product.ID = ID
	log.Printf("%s:  ProductID: %s\n", method, product.ID)
	log.Println()

	// Timestamp in Unix Nanoseconds
	timestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s:  Error getting timestamp", method)
	}

	product.Timestamp = timestamp.Seconds

	// ID of product is the hash of username + unique Salt
	err = s.putProductState(ctx, product, 0)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s:  end\n", method)
	return product.ID, nil
}

// Validate Create/Update/Delete Operations
func (s *DataContract) validateCUD(ctx TransactionContextInterface, product *Product, op int) error {
	method := "validateCUD"
	log.Printf("%s:  start\n", method)

	//////////////////////// 
	//////////////////////// 
	//////////////////////// PERMISSION CHECKS 
	//////////////////////// 
	//////////////////////// 

	/* Check Owner existence */
	err := s.assertUserExists(ctx)
	if err != nil {
		return fmt.Errorf("ValidationError: %v", err)
	}

	/* Check Ownership */
	if op == 1 {
		val, err := s.IsOwner(ctx, product.ID)
		if err != nil {
			return fmt.Errorf("ValidationError: %v", err)
		}

		if !val {
			return fmt.Errorf("ValidationError: Caller is not the owner of this product")
		}
	}

	//////////////////////// 
	//////////////////////// 
	//////////////////////// ARGUMENT VALIDATION 
	//////////////////////// 
	//////////////////////// 
	policy := product.Policy

	// Price
	if product.Price < 0 {
		return fmt.Errorf("ValidationError: Negative value for price")
	}

	// Consent
	if policy.InclPersonalInfo && !policy.HasConsent {
		return fmt.Errorf("ValidationError: No consent to sell non personal data")
	}

	// Purposes
	if product.ProductType != ANALYTICS {
		if len(policy.Purposes) == 0 {
			return fmt.Errorf("ValidationError: No purpose of buying stated")
		}

		err = validateValues(policy.Purposes, PURPOSES)
		if err != nil {
			return fmt.Errorf("ValidationError: %v", err)
		}
	} 
	// else {
	// 	if len(policy.Purposes) > 0 {
	// 		return fmt.Errorf("ValidationError: Cannot state purposes for product of type: %s", product.ProductType)
	// 	}
	// }

	// Defined values
	if !_in(product.Sector, PRODUCT_SECTOR[:]) {
		return fmt.Errorf("ValidationError: Missing Sector or Wrong Value")
	}

	if !_in(product.ProductType, PRODUCT_TYPES[:]) {
		return fmt.Errorf("ValidationError: Missing ProductType or Wrong Value")
	}

	// Org PreApproval
	if product.Sector == EDUCATION && len(policy.ApprovedOrgs) > 0 {
		return fmt.Errorf("ValidationError: Cannot pre approve orgs on this sector: %s", product.Sector)
	}

	if product.Sector == HEALTH && len(policy.ApprovedOrgs) == 0 && product.ProductType != ANALYTICS {
		return fmt.Errorf("ValidationError: Missing pre approved orgs for product of type: %s", product.ProductType)
	}

	// Institution Types. 
	// All EDUCATION product types must have institution types
	// For HEALTH products, only analytics have institution types 
	if (product.Sector == EDUCATION || product.ProductType == ANALYTICS) && len(policy.RecipientType) == 0 {
		return fmt.Errorf("ValidationError: No Institution types selected")
	}	

	// Validate Institution types 
	if product.Sector == HEALTH && product.ProductType == ANALYTICS {
		err = validateValues(product.Policy.RecipientType, HEALTH_INSTITUTION_TYPES)
	} else if product.Sector == EDUCATION {
		err = validateValues(product.Policy.RecipientType, EDUCATIONAL_INSTITUTION_TYPES)
	}
	if err != nil {
		return fmt.Errorf("ValidationError: %v", err)
	}

	// Automated Decision Making Consequences
	if product.ProductType != ANALYTICS && _in(AUTOMATED_DECISION_MAKING, policy.Purposes) {
		if len(policy.AutomatedDecisionMaking) == 0 {
			return fmt.Errorf("ValidationError: No Automated Decision Making Consequences selected")
		}

		err = validateValues(policy.AutomatedDecisionMaking, AUTOMATED_DECISION_MAKING_CONSEQUENCES)
		if err != nil {
			return fmt.Errorf("ValidationError: %v", err)
		}
	}

	// Check curation base product existence
	if len(product.Curations) > 0 {
		exists, err := s.ProductExists(ctx, product.Curations[len(product.Curations) -1])
		if err != nil {
			return fmt.Errorf("ValidationError: %v", err)
		}

		if !exists {
			return fmt.Errorf("ValidationError: Curation base product %s does not exist", product.Curations[len(product.Curations)-1])
		}
	}

	// Protection
	if !_in(policy.ProtectionType, PROTECTIONS) {
		return fmt.Errorf("ValidationError: Unhandled Protection Type: %s", policy.ProtectionType)
	}

	// User PreApproval
	tmp_array := []string{}
	for _, buyerUsername := range policy.ApprovedUsers {
		buyer, err := userContract.ReadUser(ctx, buyerUsername)
		if err != nil {
			fmt.Errorf("ValidationError: %v", err)
		}

		if buyer != nil {
			tmp_array = append(tmp_array, buyer.ID)	
		}
	}

	product.Policy.ApprovedUsers = make([]string, len(tmp_array))
	copy(product.Policy.ApprovedUsers, tmp_array)
	log.Printf("%s:  end\n", method)
	return nil
}


// UpdateProduct Update a product by ID (owner only)
func (s *DataContract) UpdateProduct(ctx TransactionContextInterface, productStr string) error {
	method := "UpdateProduct"
	log.Printf("%s:  start\n", method)

	// Get product object
	product, err := s.getProdFromString(productStr)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}
	
	// Validate existence, ownership and args
	if err = s.validateCUD(ctx, product, 1); err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	product.ObjectType = PRODUCT_OBJECT_TYPE
	product.Owner = ctx.GetData().Username

	if err := s.putProductState(ctx, product, 1); err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s:  end\n", method)
	return nil
}

// BuyProduct Validates buyer's and seller's status, policy, and creates an agreement
func (s *DataContract) BuyProduct(ctx TransactionContextInterface, productID string, buyerParams BuyerParams) (string, error) {
	method := "BuyProduct"
	log.Printf("%s:  start\n", method)

	product, err := s.getProduct(ctx, productID)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	if ctx.GetData().IsBuyer != true {
		return EMPTY_STR, fmt.Errorf("%s:  User is not a registered buyer", method)
	}

	// Reject if owner tries to buy own product
	// if ctx.GetData().Username == product.Owner {
	// 	return EMPTY_STR, fmt.Errorf("%s:  User %s is owner of this product: %s", method, ctx.GetData().Username, productID)
	// }

	// Check if seller has exired certificate
	seller, err := userContract.ReadUser(ctx, product.Owner)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	if seller == nil {
		return EMPTY_STR, fmt.Errorf("%s: User %s does not exist", method, product.Owner)
	}

	if seller.ValidTo.Unix() < time.Now().Unix() {
		return EMPTY_STR, fmt.Errorf("%s:  Seller %s has expired certificate", method, seller.Username)
	}

	// Check for seller revoked certificate
	// err = managementContract.assertNotRevokedCertificate(ctx, seller.CertKey, seller.MspID)
	// if err != nil {
	// 	return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	// }

	// Check for Inactive User
	if seller.Active != true {
		return EMPTY_STR, fmt.Errorf("%s:  Seller %s is inactive", method, seller.Username)
	}

	// Check eligibility
	isEligible, err := agreementContract.IsEligible(ctx, product, buyerParams)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	if isEligible == false {
		return EMPTY_STR, fmt.Errorf("%s:  User %s is not eligible to transact this product: %s", method, ctx.GetData().Username, productID)
	}

	transactionID, err := agreementContract.newAgreement(ctx, *product)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s:  TransactionID: %s\n", method, transactionID)
	return transactionID, nil
}

// DeleteProduct Delete a product by ID (owner only)
func (s *DataContract) DeleteProduct(ctx TransactionContextInterface, productID string) error {
	method := "DeleteProduct"
	log.Printf("%s:  start\n", method)

	// Validate Existence and Ownership
	isOwner, err := s.IsOwner(ctx, productID)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	if !isOwner {
		log.Printf("%s:  Not Owner\n", method)
		return fmt.Errorf("%s:  User %s is not the owner of the product %s", method, ctx.GetData().Username, productID)
	}

	// Delete Product STATE
	key := s.makeProductKey(ctx, productID)
	product, err := s.getProduct(ctx, productID)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	productBytes, err := json.Marshal(product)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	err = ctx.GetStub().DelState(key)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	// Update User Inventory
	if err = putUserInventoryState(ctx, ctx.GetData().Username, 2); err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	// Fire Event
	ctx.GetStub().SetEvent("DeleteProduct", productBytes)
	log.Printf("%s:  end\n", method)
	return nil
}

// Assign an ID to a new Product
func (s *DataContract) createProductID(ctx TransactionContextInterface, owner string) (string, error) {
	method := "createProductID"
	log.Printf("%s:  start\n", method)

	/* Fetch User Inventory to get Salt */
	key, _ := ctx.GetStub().CreateCompositeKey(INVENTORY_OBJECT_TYPE, []string{owner})
	userInvBytes, err := ctx.GetStub().GetState(key)
	if err != nil {
		log.Printf("%s:  Error getting state userInventory", method)
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	/* Get Salt */
	var userInv UserInventory
	err = json.Unmarshal(userInvBytes, &userInv)
	if err != nil {
		log.Printf("%s:  Error Unmarshal userInventory", method)
		return EMPTY_STR, fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s:  Count and Salt: %j\n", method, userInv)

	/* Create ID as hash(owner + salt) */
	hashBytes := sha256.Sum256([]byte(owner + strconv.Itoa(userInv.Salt)))

	log.Printf("%s:  end\n", method)
	return hex.EncodeToString(hashBytes[:]), nil
}

// Update User Inventory STATE
func putUserInventoryState(ctx TransactionContextInterface, username string, op int) error {
	method := "putUserInventoryState"
	log.Printf("%s:  start\n", method)

	/* Get User Inventory STATE */
	key, _ := ctx.GetStub().CreateCompositeKey(INVENTORY_OBJECT_TYPE, []string{username})
	userInvBytes, err := ctx.GetStub().GetState(key)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	var userInv UserInventory

	/* Update STATE */
	if op == 0 {
		userInv := UserInventory{}
		userInv.Count = 0
		userInv.Salt = 0
	} else {

		err = json.Unmarshal(userInvBytes, &userInv)
		printUser, err := json.MarshalIndent(userInv, "\t", " ")
		fmt.Printf("\n%s\n", printUser)
		if err != nil {
			return fmt.Errorf("%s: %v", method, err)
		}

		if op == 1 {
			userInv.Count++
			userInv.Salt++
		} else if op == 2 {
			userInv.Count--

		}
	}

	/* Marshal User Inventory */
	userInv.ObjectType = INVENTORY_OBJECT_TYPE
	userInvJSON, err := json.Marshal(userInv)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	/* Put User Inventory STATE */
	err = ctx.GetStub().PutState(key, userInvJSON)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s:  end\n", method)
	return nil
}

// Put Product STATE
func (s *DataContract) putProductState(ctx TransactionContextInterface, product *Product, op int) error {
	method := "putProductState"
	log.Printf("%s:  start\n", method)

	/* Make key */
	key := s.makeProductKey(ctx, product.ID)

	/* Marshal product */
	productBytes, err := json.Marshal(product)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	/* Put Product STATE */
	err = ctx.GetStub().PutState(key, productBytes)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	if op == 0 {
		/* Update Owner's Inventory */
		err = putUserInventoryState(ctx, product.Owner, 1)
		if err != nil {
			return fmt.Errorf("%s: %v", method, err)
		}

		ctx.GetStub().SetEvent("CreateProduct", productBytes)
	} else if op == 1 {
		ctx.GetStub().SetEvent("UpdateProduct", productBytes)
	}

	log.Printf("%s:  end\n", method)
	return nil
}

// Convert Product String to Product Object
func (s *DataContract) getProdFromString(productStr string) (*Product, error) {
	method := "putProductState"
	log.Printf("%s: Decoding product string\n", method)

	var product *Product
	err := json.Unmarshal([]byte(productStr), &product)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s: Decoded product\n", method)
	return product, nil
}

// ProductExists Checks a product for existence
func (s *DataContract) ProductExists(ctx TransactionContextInterface, productID string) (bool, error) {
	key, _ := ctx.GetStub().CreateCompositeKey(PRODUCT_OBJECT_TYPE, []string{productID})
	productBytes, err := ctx.GetStub().GetState(key)
	if err != nil {
		return false, err
	}

	return productBytes != nil, nil
}

// assertUserExists Checks if caller exists
func (s *DataContract) assertUserExists(ctx TransactionContextInterface) error {
	username := ctx.GetData().Username
	if username == EMPTY_STR {
		return fmt.Errorf("User does not exist")
	}

	return nil
}

// IsOwner Checks if caller is owner of a product
func (s *DataContract) IsOwner(ctx TransactionContextInterface, productID string) (bool, error) {
	err := s.assertUserExists(ctx)
	if err != nil {
		return false, err
	}

	product, err := s.getProduct(ctx, productID)
	if err != nil {
		return false, err
	}

	if ctx.GetData().Username != product.Owner {
		return false, nil
	}

	return true, nil
}

func (s *DataContract) makeProductKey(ctx TransactionContextInterface, productID string) string {
	key, _ := ctx.GetStub().CreateCompositeKey(PRODUCT_OBJECT_TYPE, []string{productID})

	return key
}

func (s *DataContract) Test() {
	log.Println("Testing...")
}
