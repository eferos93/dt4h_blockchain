package dt4h

import (
	"encoding/json"
	"fmt"

	"github.com/golang/protobuf/ptypes"
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

		product, err := s.parseProductBytes(queryResponse.Value)
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		products = append(products, product)
	}

	return products, nil
}

// GetProductHistory fetch modification history of a product
func (s *DataContract) GetProductHistory(ctx TransactionContextInterface, productID string) ([]ProductHistoryQueryResult, error) {
	method := "GetProductHistory"

	key := s.makeProductKey(ctx, productID)
	resultsIterator, err := ctx.GetStub().GetHistoryForKey(key)

	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer resultsIterator.Close()

	var records []ProductHistoryQueryResult
	for resultsIterator.HasNext() {
		response, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		var product Product
		if len(response.Value) > 0 {
			err = json.Unmarshal(response.Value, &product)
			if err != nil {
				return nil, fmt.Errorf("%s: %v", method, err)
			}
		} else {
			product = Product{
				ID: productID,
			}
		}

		timestamp, err := ptypes.Timestamp(response.Timestamp)
		if err != nil {
			return nil, err
		}

		record := ProductHistoryQueryResult{
			TxId:      response.TxId,
			Timestamp: timestamp,
			Record:    &product,
			IsDelete:  response.IsDelete,
		}
		records = append(records, record)
	}

	return records, nil
}

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

	product, err := s.parseProductBytes(productBytes)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return product, nil
}

// Parse product bytes based on the current version
func (s *DataContract) parseProductBytes(productBytes []byte) (*Product, error) {
	method := "parseProduct"

	// Unmarshal to a map to check version and values
	mapping, err := getMapping(productBytes)
	if err != nil {
		return nil, err
	}

	version, ok := mapping[VERSION_FIELD].(float64)
	if !ok {
		return nil, fmt.Errorf("%s - error decoding product version", method)
	}

	if version == CURRENT_PRODUCT_VERSION {
		fmt.Printf("%s - Latest Version: %v", method, version)

		// Change value here
		// mapping[VERSION_FIELD] = 1
		productBytes, err = json.Marshal(mapping)
		if err != nil {
			return nil, err
		}
	}

	var product *Product
	err = json.Unmarshal(productBytes, &product)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return product, nil
}
