package dt4h

import "log"

/* Import required libs */

// "github.com/hyperledger/fabric-contract-api-go/contractapi"

func (s *QueryContract) LogQuery(ctx TransactionContextInterface, query string) error {
	user := ctx.GetData()
	err := ctx.GetStub().PutState(user, []byte(query))
	return err
}

func (s *QueryContract) GetUserHistory(ctx TransactionContextInterface, user string) (*UserHistory, error) {
	userId := ctx.GetData()
	log.Default().Printf("UserID: %s", userId)
	resultIterator, err := ctx.GetStub().GetHistoryForKey(userId)
	if err != nil {
		return nil, err
	}
	defer resultIterator.Close()

	var history []Query
	for resultIterator.HasNext() {
		queryResponse, err := resultIterator.Next()
		if err != nil {
			return nil, err
		}
		history = append(history, Query{string(queryResponse.Value), string(queryResponse.GetTimestamp().AsTime().String())})
	}

	return &UserHistory{userId, history}, nil
}
