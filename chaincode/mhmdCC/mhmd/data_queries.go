package mhmd

import (
	"encoding/json"
	"fmt"
)

// ReadProduct Get a product by ID
func (s *DataContract) ReadProduct(ctx TransactionContextInterface, productID string) (*Product, error) {
	method := "ReadProduct"

	product, err := s.getProduct(ctx, productID)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return product, nil
}

// GetAllProducts Query all products
func (s *DataContract) GetAllProducts(ctx TransactionContextInterface) ([]*Product, error) {
	method := "GetAllProducts"

	resultsIterator, err := ctx.GetStub().GetStateByPartialCompositeKey(PRODUCT_OBJECT_TYPE, nil)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer resultsIterator.Close()

	var products []*Product
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		var product *Product
		err = json.Unmarshal(queryResponse.Value, &product)
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}
		products = append(products, product)
	}

	return products, nil
}

// func (s *DataContract) GetHistoryOfProduct(ctx TransactionContextInterface, productID string) (*[]Agreement, error) {

// }

// getProduct fetch a product
func (s *DataContract) getProduct(ctx TransactionContextInterface, productID string) (*Product, error) {
	method := "getProduct"

	key := s.makeProductKey(ctx, productID)
	productBytes, err := ctx.GetStub().GetState(key)

	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	if productBytes == nil {
		return nil, fmt.Errorf("%s: Product %s does not exist", method, productID)
	}

	var product *Product
	err = json.Unmarshal(productBytes, &product)

	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return product, nil
}
