package agora

import (
	"encoding/json"
	"fmt"
	"log"

	"github.com/golang/protobuf/ptypes"
)

func (s *AgreementContract) GetTransactionHistoryOfProduct(ctx TransactionContextInterface, productID string) ([]ProductTxtHistoryQueryResult, error) {
	const method = "GetTransactionHistoryOfProduct"
	log.Printf("%s - Search Product ID: %s\n", method, productID)

	key, _ := ctx.GetStub().CreateCompositeKey(PRODUCT_OBJECT_TYPE, []string{productID})

	resultsIterator, err := ctx.GetStub().GetHistoryForKey(key)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer resultsIterator.Close()

	var records []ProductTxtHistoryQueryResult
	for resultsIterator.HasNext() {
		log.Printf("%s - Search Product ID: %s\n", method, productID)
		response, err := resultsIterator.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		var agreement Agreement
		if len(response.Value) > 0 {
			err = json.Unmarshal(response.Value, &agreement)
			if err != nil {
				return nil, fmt.Errorf("%s: %v", method, err)
			}
		} else {
			agreement = Agreement{
				ProductID: productID,
			}
		}

		timestamp, err := ptypes.Timestamp(response.Timestamp)
		if err != nil {
			return nil, fmt.Errorf("%s: %v", method, err)
		}

		record := ProductTxtHistoryQueryResult{
			TxId:      response.TxId,
			Timestamp: timestamp,
			Record:    &agreement,
			IsDelete:  response.IsDelete,
		}
		records = append(records, record)
	}

	return records, nil

}
