package mhmd

import (
	"encoding/json"
	"fmt"
)

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

		var user *User
		err = json.Unmarshal(queryResponse.Value, &user)
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