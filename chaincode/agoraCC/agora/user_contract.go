package agora

import (
	"crypto/sha256"
	X509 "crypto/x509"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log"
	"strconv"

	"github.com/hyperledger/fabric-chaincode-go/pkg/cid"

	// "time"
	// "strconv"
	// "strings"
)

// CreateUser Creates a user using certificate as ID
func (s *UserContract) CreateUser(ctx TransactionContextInterface, userStr string) error {
	method := "CreateUser"
	log.Printf("%s - start\n", method)

	/* Get user object from rich string */
	user, err := s.getUserFromString(userStr)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%+v", user)
	/* Assign fabric ID */
	user.ObjectType = USER_OBJECT_TYPE
	userID, _ := ctx.GetClientIdentity().GetID()
	user.ID = userID
	user.MspID, _ = ctx.GetClientIdentity().GetMSPID()
	user.Active = true
	user.ValidTo, user.CertKey = updateCertData(ctx)
	if user.CertKey == EMPTY_STR {
		return fmt.Errorf("%s - Error Updating Certificate Data", method)
	}
	log.Printf("%s - ", method, user.CertKey)
	// TODO: IF IS ORG TRUE, CHECK IF ORGNAME IS EMPTY
	// if user.IsOrg != true {
	// 	user.Org = {0};
	// }

	// if !user.IsBuyer {
	// }

	/* Validate ID and Args */
	err = s.validateCUD(ctx, user, 0)
	log.Printf("%+v", user)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	/* Store user to STATE */
	err = s.putUserState(ctx, user, 0)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	/* Init and store user inventory to STATE */
	err = putUserInventoryState(ctx, user.Username, 0)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	/* ------ Optional */

	// Store key: (ID:username) to STATE
	key, _ := ctx.GetStub().CreateCompositeKey(USERID_OBJECT_TYPE, []string{userID})
	err = ctx.GetStub().PutState(key, []byte(user.Username))
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	/* ------ Optional */

	log.Printf("%s - end\n", method)

	return nil
}

// UpdateUser Update a user(self, owner only)
func (s *UserContract) UpdateUser(ctx TransactionContextInterface, userStr string) error {
	method := "UpdateUser"
	log.Printf("%s - start\n", method)

	/* Get user object from rich string */
	user, err := s.getUserFromString(userStr)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	/* Assign fabric ID */
	user.ObjectType = USER_OBJECT_TYPE
	user.ID = ctx.GetData().ID
	user.Username = ctx.GetData().Username
	user.MspID, _ = ctx.GetClientIdentity().GetMSPID()
	user.Active = true	
	user.ValidTo, user.CertKey = updateCertData(ctx)
	if err != nil {
		return fmt.Errorf("%s - Error Updating Certificate Data", method)
	}
	
	// if (!user.IsOrg) {
	// 	user.Org = {};
	// }

	// if !user.IsBuyer {
	// 	user.Purposes = []string{}
	// }

	/* Validate ID and Args */
	if err = s.validateCUD(ctx, user, 1); err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	/* Put new state */
	err = s.putUserState(ctx, user, 1)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s - end\n", method)
	return nil
}

// ReadUser Fetch a user by username. Returns nil if doesn't exist
func (s *UserContract) ReadUser(ctx TransactionContextInterface, username string) (*User, error) {
	method := "ReadUser"
	log.Printf("%s - start\n", method)

	userBytes, err := s.getUserJSON(ctx, username)
	if err != nil {
		return nil, fmt.Errorf("failed to read world state")
	}

	if userBytes == nil {
		return nil, nil
	}

	var user *User
	err = json.Unmarshal(userBytes, &user)

	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s - end\n", method)

	return user, nil
}

// DeleteUser (self, owner only)
// Username arg is not used yet, left for future admin implementation
func (s *UserContract) DeleteUser(ctx TransactionContextInterface, username string) error {
	method := "DeleteUser"
	log.Printf("%s - start\n", method)

	userID := ctx.GetData().Username

	// TODO: ADMIN

	if len(userID) < 1 {
		return fmt.Errorf("%s: user does not exist", method)
	}

	key := s.makeUserKey(ctx, userID)
	if key == EMPTY_STR {
		fmt.Errorf("%s: error creating key", method)
	}

	user, err := s.ReadUser(ctx, userID)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	userBytes, err := json.Marshal(user)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	err = ctx.GetStub().DelState(key)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	userInv, err := getInventory(ctx)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s - Inventory: %+v\n", method, *userInv)

	deletedCount := 0
	for i := 0; i < userInv.Salt; i++ {
		hashBytes := sha256.Sum256([]byte(userID + strconv.Itoa(i)))
		hash := hex.EncodeToString(hashBytes[:])
		key, _ := ctx.GetStub().CreateCompositeKey(PRODUCT_OBJECT_TYPE, []string{hash})
		productBytes, err := ctx.GetStub().GetState(key)
		if err != nil {
			return fmt.Errorf("%s: %v", method, err)
		}

		if productBytes != nil {
			err = ctx.GetStub().DelState(key)
			if err != nil {
				return fmt.Errorf("%s: %v", method, err)
			}

			log.Printf("%s - Deleted ID: %s\n ", method, hash)
			deletedCount++
		}
	}

	if deletedCount != userInv.Count {
		return fmt.Errorf("error deleting products")
	}

	key, _ = ctx.GetStub().CreateCompositeKey(USERID_OBJECT_TYPE, []string{user.ID})
	err = ctx.GetStub().DelState(key)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	key, _ = ctx.GetStub().CreateCompositeKey(INVENTORY_OBJECT_TYPE, []string{userID})
	err = ctx.GetStub().DelState(key)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	ctx.GetStub().SetEvent("DeleteUser", userBytes)

	log.Printf("%s - end\n", method)

	return nil
}

// InactivateUser An admin makes a user inactive
func (s *UserContract) InactivateUser(ctx TransactionContextInterface, username string) error {
	method := "InactivateUser"

	user, err := s.ReadUser(ctx, username)
	if err != nil {
		return fmt.Errorf("%s - ", method, err)
	}

	// Authorization checks
	hasOuValue, err := cid.HasOUValue(ctx.GetStub(), CLIENT)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	if !hasOuValue {
		return fmt.Errorf("%s - OU value is not %s", method, CLIENT)
	}

	callerMSP, _ := ctx.GetClientIdentity().GetMSPID() 
	if user.MspID != callerMSP {
		return fmt.Errorf("%s - AuthorizationError: User %s belongs to another MSP", method, username)
	}

	user.Active = false

	/* Put new state */
	err = s.putUserState(ctx, user, 1)
	if err != nil {
		return fmt.Errorf("%s - ", method, err)
	}

	return nil
}






/* Account Recovery
1. User sets a Hashed strong Key as input when they register or later
2. When User needs to recoverAccount, they must pass the raw key as input to this function
3. The raw key is hashed and checked against the saved Hashed Key
4. If they match, data ownership of oldCert is passed to newCert
5. Since the raw key will be seen, it will be intended for 1 time use only.
   The User must set a new hashed Key for the next recovery.

Hash function: sha256.Sum256
*/
// AccountRecovery Recover an account upon expiration of certificate
// func (s *UserContract) AccountRecovery(ctx TransactionContextInterface, username string, recoveryKey string) (error) {

// 	// Hash input key
// 	hashBytes := sha256.Sum256([]byte(recoveryKey);
// 	hash = hex.EncodeToString(hashBytes[:]);
// 	if hash == nil {
// 		return fmt.Errorf("Error on hashing input");
// 	}

// 	// Fetch User obj
// 	User, err = ReadUser(ctx, username);
// 	if err != nil {
// 		return fmt.Errorf("Error reading user");
// 	}

// 	// Validate Recovery Key
// 	if hash != User.RecoveryHash {
// 		return fmt.Errorf("Error: Wrong Recovery Key");
// 	}

// 	// Store new ID key: (ID:username) to STATE
// 	key, _ := ctx.GetStub().CreateCompositeKey(USERID_OBJECT_TYPE, []string{userID})
// 	err = ctx.GetStub().PutState(key, []byte(user.Username))
// 	if err != nil {
// 		return fmt.Errorf("%s: %v", method, err)
// 	}

// 	// Put new UserID state
// 	User.ID = ctx.GetClientIdentity.GetID();

// 	// Put new User state with changed ID
// 	err = s.putUserState(ctx, user, 1)
// 	if err != nil {
// 		return fmt.Errorf("%s: %v", method, err)
// 	}
// }

/*
 *** **************** ****
 *** HELPER FUNCTIONS ****
 *** **************** ****
 */

// Get user from json rich string
func (s *UserContract) getUserFromString(userStr string) (*User, error) {
	method := "getUserFromString"

	var user *User
	err := json.Unmarshal([]byte(userStr), &user)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	// log.Printf("%s - User:\n", method, user)
	return user, nil
}

// Put user state
func (s *UserContract) putUserState(ctx TransactionContextInterface, user *User, op int) error {
	method := "putUserState"

	// Make key
	key := s.makeUserKey(ctx, user.Username)
	if key == EMPTY_STR {
		return fmt.Errorf("failed to create composite key")
	}

	// Interface -> bytes
	userBytes, err := json.Marshal(user)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	// Put user state
	err = ctx.GetStub().PutState(key, userBytes)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	if op == 0 {
		ctx.GetStub().SetEvent("CreateUser", userBytes)
	} else if op == 1 {
		ctx.GetStub().SetEvent("UpdateUser", userBytes)
	}

	// if user.IsOrg {
	// 	// Make Org Key
	// 	key, err := ctx.GetStub().CreateCompositeKey(ORG_OBJECT_TYPE, []string{user.ID})
	// 	if err != nil {
	// 		return fmt.Errorf("%s: %v", method, err)
	// 	}

	// 	// Interface -> Bytes
	// 	orgData := {
	// 		Verified 
	// 	}

	// }

	return nil
}

// Validate ownership and args
func (s *UserContract) validateCUD(ctx TransactionContextInterface, user *User, op int) error {
	method := "ValidationError"
	log.Printf("%s - start", method)

	if len(user.Username) < 4 {
		return fmt.Errorf("%s: Username length must be more than 4", method)
	}

	userBytes, err := s.getUserJSON(ctx, user.Username)
	if err != nil {
		return fmt.Errorf("%s - failed to read from world state", method)
	}

	if op == 0 {

		/* Create User */
		log.Printf("%s - Validating create user\n", method)

		/* Is the user already registered? */
		key, _ := ctx.GetStub().CreateCompositeKey(USERID_OBJECT_TYPE, []string{ctx.GetData().ID})
		usernameBytes, err := ctx.GetStub().GetState(key)
		if err != nil {
			return fmt.Errorf("%s: %v", method, err)
		}

		if usernameBytes != nil {
			log.Printf("%s - user %s is already registered", method, user.ID)
			return fmt.Errorf("%s - identity: %s is already registered", method, user.ID)
		}

		/* Does username exist? */
		if userBytes != nil {
			return fmt.Errorf("%s - username %s already exists", method, user.Username)
		}

	} else if op == 1 || op == 2 {

		/* Update/Delete User */
		log.Printf("%s - Validating update/delete user\n", method)

		/* Check user existence */
		if userBytes == nil {
			return fmt.Errorf("%s - user %s does not exist", method, user.Username)
		}

		/* Check Ownership */
		if ctx.GetData().Username != user.Username {
			return fmt.Errorf("%s - Username Mismatch. Caller is not the owner of this account", method)
		}

		/* Check Ownership */
		if ctx.GetData().ID != user.ID {
			return fmt.Errorf("%s - ID Mismatch. Caller is not the owner of this account", method)
		}

		if op == 2 {
			return nil
		}

	}

	/* Validate arguments */

	// Set purpose preferences for buyer
	if user.IsBuyer {
		if len(user.Purposes) == 0 {
			user.Purposes = []string{}
		} else {
			err = validateValues(user.Purposes, PURPOSES)
			if err != nil {
				return fmt.Errorf("%s: %v", method, err)
			}
		}
	}

	// Member of Organization 
	if user.IsMemberOf != EMPTY_STR {
		// DEV COMMENT START
		// if user.IsOrg {
		// 	return fmt.Errorf("%s - Cannot be both member and organization (IsMemberOf, IsOrg)", method)
		// }
		// DEV END

		// user.Org.initOrg()

		////////////////////////////  Append member to Org.Members, FOR DEV ONLY 
		// DEV START
		// org, err := s.ReadUser(ctx, user.IsMemberOf)
		// if err != nil {
		// 	return fmt.Errorf("%s - ", method, err)
		// }

		// if org == nil {
		// 	return fmt.Errorf("%s: Org %s does not exist", method, user.IsMemberOf)
		// }

		// // CHECK THAT ISORG = TRUE
		// if org.IsOrg == false {
		// 	return fmt.Errorf("%s: User %s is not an org: (IsOrg=false)", method, user.IsMemberOf)
		// }

		// if !_in(user.ID, org.Org.Members) {
		// 	org.Org.Members = append(org.Org.Members, user.ID)

		// 	// Make key
		// 	key := s.makeUserKey(ctx, org.Username)
		// 	log.Printf(key)
		// 	if key == EMPTY_STR {
		// 		return fmt.Errorf("%s: failed to create composite key", method)
		// 	}

		// 	// Interface -> bytes
		// 	orgJSON, err := json.Marshal(org)
		// 	log.Printf(string(orgJSON))
		// 	if err != nil {
		// 		return fmt.Errorf("%s: %v", method, err)
		// 	}

		// 	// Put user state
		// 	err = ctx.GetStub().PutState(key, orgJSON)
		// 	if err != nil {
		// 		return fmt.Errorf("%s: %v", method, err)
		// 	}
		// }
		// DEV END
	}

	// Organization
	if user.IsOrg {
		err = user.Org.validateOrgArgs()
		if err != nil {
			return fmt.Errorf("%s: %v", method, err)
		}
	} else {
		user.Org.initOrg()
	}

	log.Printf("%+v", user.Org)
	log.Printf("%s - end\n", method)
	return nil
}


// makeUserKey Create user key
func (s *UserContract) makeUserKey(ctx TransactionContextInterface, username string) string {
	key, err := ctx.GetStub().CreateCompositeKey(USER_OBJECT_TYPE, []string{username})
	if err != nil {
		return EMPTY_STR
	}

	return key
}

// getUserJSON Fetch user from world state
func (s *UserContract) getUserJSON(ctx TransactionContextInterface, username string) ([]byte, error) {
	method := "getUserJSON"

	key := s.makeUserKey(ctx, username)
	userJSON, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return userJSON, nil
}

/*
 *** **************** ****
 *** * TEST FUNCTIONS ****
 *** **************** ****
 */

// GetClass Get class of user
func (s *UserContract) GetClass() string {
	return USER_OBJECT_TYPE
}

// GetCtx
func (s *UserContract) GetCtx(ctx TransactionContextInterface) {
	val, _ := ctx.GetClientIdentity().GetID()
	fmt.Printf("%s\n", val)
	val, _ = ctx.GetClientIdentity().GetMSPID()
	fmt.Printf("%s\n", val)
	var cert *X509.Certificate
	cert, _ = ctx.GetClientIdentity().GetX509Certificate()
	certJSON, _ := json.MarshalIndent(cert, EMPTY_STR, " ")
	fmt.Printf("%s\n", certJSON)
}

// Test testing
func (s *UserContract) Test(user string) *User {
	log.Println("TESTING")
	log.Println("TESTING")
	log.Println("TESTING")
	log.Println("data: ", user)
	// Make User Object
	var use *User
	// r := []byte(user)
	err := json.Unmarshal([]byte(user), &use)
	if err != nil {
		log.Println("error", err)
	}

	log.Println("\nID: ", use.ID)
	// log.Println("\nValue: ", use.Value)

	res := use
	return res
}
