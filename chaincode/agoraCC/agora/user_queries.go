package agora

import (
	"encoding/json"
	"fmt"
)

// ReadUser Fetch a user by username. Returns nil if doesn't exist
func (s *UserContract) ReadUser(ctx TransactionContextInterface, username string) (*User, error) {
	method := "ReadUser"

	user, err := s.getUser(ctx, username)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method)
	}


	return user, nil
}


// getUser Fetch user from world state
func (s *UserContract) getUserBytes(ctx TransactionContextInterface, username string) ([]byte, error) {
	method := "getUser"

	key := s.makeUserKey(ctx, username)
	userBytes, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return userBytes, nil
}

// getUser Fetch user from world state
func (s *UserContract) getUser(ctx TransactionContextInterface, username string) (*User, error) {
	method := "getUser"

	key := s.makeUserKey(ctx, username)
	userBytes, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	if userBytes == nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	user, err := s.parseUserBytes(userBytes)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return user, nil
}

// Query all users
func (s *UserContract) GetAllUsers(ctx TransactionContextInterface) ([]*User, error) {
	method := "GetAllUsers"
	
	resultsIterator, err := ctx.GetStub().GetStateByPartialCompositeKey(USER_OBJECT_TYPE, nil)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer resultsIterator.Close()

	var users []*User
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		user, err := s.parseUserBytes(queryResponse.Value)
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		users = append(users, user)
	}

	return users, nil
}

// Query all inventories
func (s *UserContract) GetUserInventories(ctx TransactionContextInterface) ([]*UserInventory, error) {
	method := "GetUserInventories"

	resultsIterator, err := ctx.GetStub().GetStateByPartialCompositeKey(INVENTORY_OBJECT_TYPE, nil)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer resultsIterator.Close()

	var inventories []*UserInventory
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		var userInv *UserInventory
		err = json.Unmarshal(queryResponse.Value, &userInv)
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}
		printUser, err := json.MarshalIndent(userInv, "\t", " ")
		fmt.Printf("\n%s\n", printUser)
		inventories = append(inventories, userInv)
	}

	return inventories, nil

}

func getInventory(ctx TransactionContextInterface) (*UserInventory, error) {
	method := "getInventory"

	key, _ := ctx.GetStub().CreateCompositeKey(INVENTORY_OBJECT_TYPE, []string{ctx.GetData().Username})
	invBytes, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	
	var inv *UserInventory
	err = json.Unmarshal(invBytes, &inv);
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return inv, nil
}

// Parse user bytes based on the current version
func (s *UserContract) parseUserBytes(userBytes []byte) (*User, error) {
	method := "parseUserBytes"

	// Unmarshal to a map to check version and values
	mapping, err := getMapping(userBytes)
	if err != nil {
		return nil, err
	}

	version, ok := mapping["_v"].(float64)
	if !ok {
		return nil, fmt.Errorf("%s - error decoding user version", method)
	}

	if version == CURRENT_USER_VERSION {
		fmt.Printf("%s - Latest Version: %v", method, version)
		
		// Change value here
		// mapping["_v"] = 1
		// mapping["desc"] = "Test desc change"
		userBytes, err = json.Marshal(mapping)
		if err != nil {
			return nil, err
		}
	}


	var user *User
	err = json.Unmarshal(userBytes, &user)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}	

	return user, nil
}