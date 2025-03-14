package dt4h

import (
	X509 "crypto/x509"
	"encoding/json"
	"fmt"

	// age "github.com/bearbin/go-age"
	"log"
	// "strconv"
	"time"
)

func (e *Error) Error() string {
	return fmt.Sprintf("Error code: %d:%s ", e.Code, e.Err)
}

func BeforeTransaction(ctx TransactionContextInterface) error {
	method := "BeforeTransaction"

	// Get user ID
	userID, err := ctx.GetClientIdentity().GetID()
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	// Create key TODO this part is more advanced, we leave it for later
	// key, _ := ctx.GetStub().CreateCompositeKey(USERID_OBJECT_TYPE, []string{userID})

	// // Get user data by ID
	// username, err := ctx.GetStub().GetState(key)
	// if err != nil {
	// 	return fmt.Errorf("%s: %v", method, err)
	// }

	// usernameString := string(username[:])
	// key, _ = ctx.GetStub().CreateCompositeKey(USER_OBJECT_TYPE, []string{usernameString})
	// userBytes, err := ctx.GetStub().GetState(key)

	// // log.Printf("%s", userBytes)
	// var _ = fmt.Printf
	// var _ = json.Marshal

	// // Save data to transaction context
	// var user *User
	// err = json.Unmarshal(userBytes, &user)
	// // if err != nil {
	// 	return fmt.Errorf("%s: %v", method, err)
	// }

	// if userBytes != nil {
	// 	ctx.SetData(*user)
	// }

	ctx.SetData(userID)
	printUser, err := json.MarshalIndent(userID, "\t", " ")
	log.Printf("User: \n%s\n", printUser)

	// fmt.Printf("%s", )
	// isExpired(ctx)
	return nil
}

func getCertExpirationDate(ctx TransactionContextInterface) time.Time {
	var cert *X509.Certificate
	cert, _ = ctx.GetClientIdentity().GetX509Certificate()

	return cert.NotAfter
}

func validateValues(input []string, values []string) error {
	if len(input) == 0 {
		return fmt.Errorf("ValidationError: Empty input")
	}

	for _, val := range input {
		exists := stringInSlice(val, values)
		if !exists {
			return fmt.Errorf("ValidationError: Undefined Type: %s", val)
		}
	}

	return nil
}

func _in(input string, arr []string) bool {
	exists := stringInSlice(input, arr)
	if exists {
		return true
	}

	return false
}

// Search for string in slice
func stringInSlice(input string, list []string) bool {
	for _, element := range list {
		if element == input {
			return true
		}
	}
	return false
}

// func updateCertData(ctx TransactionContextInterface) (time.Time, string) {
// 	// method := "UpdateCertData"

// 	certificate, err := ctx.GetClientIdentity().GetX509Certificate()
// 	if err != nil {
// 		return time.Now(), EMPTY_STR
// 	}

// 	mspid, err := ctx.GetClientIdentity().GetMSPID()
// 	if err != nil {
// 		return time.Now(), EMPTY_STR
// 	}

// 	certHash := makeCertHash(ctx, mspid, certificate.SerialNumber.String())
// 	return certificate.NotAfter, certHash
// }

// func assertCallerBelongsToOrg(ctx TransactionContextInterface) (*User, error) {
// 	method := "assertCallerBelongsToOrg"

// 	if ctx.GetData().IsMemberOf == EMPTY_STR {
// 		return nil, fmt.Errorf("%s: Does not belong to an organization", method)
// 	}

// 	userContract := new(UserContract)
// 	orgUser, err := userContract.ReadUser(ctx, ctx.GetData().IsMemberOf)
// 	if err != nil {
// 		return nil, fmt.Errorf("%s: %s", method, err)
// 	}

// 	// Org does not exist
// 	if orgUser == nil {
// 		return nil, fmt.Errorf("%s: Org does not exist", method)
// 	}

// 	// Org selected is not an org
// 	if orgUser.IsOrg != true {
// 		return nil, fmt.Errorf("%s: ID stated is not an organization", method)
// 	}

// 	// DEV COMMENT START
// 	// Caller is not a verified member of the org
// 	// if !_in(ctx.GetData().ID, orgUser.Org.Members) {
// 	// 	return orgUser, fmt.Errorf("%s: User is not a verified member of stated organization", method)
// 	// }
// 	// DEV END

// 	return orgUser, nil
// }

// Get Doc Version
func getDocVersion(b []byte) int64 {
	method := "parseVersion"

	m := make(map[string]interface{})
	err := json.Unmarshal(b, &m)
	if err != nil {
		return -1
	}

	// for k, v := range m {
	// 	fmt.Printf("%s - key[%s] value[%s]\n", method, k, v)
	// }

	val, ok := m[VERSION_FIELD].(int64)
	if ok && val == 0 {
		fmt.Printf("%s - Version: 0", method)
	}

	return val
}

func getMapping(b []byte) (map[string]interface{}, error) {

	m := make(map[string]interface{})
	err := json.Unmarshal(b, &m)
	if err != nil {
		return nil, err
	}
	for k, v := range m {
		fmt.Printf("key[%s] value[%s]\n", k, v)
	}
	return m, nil
}
