package dt4h

/* Import required libs */

// "github.com/hyperledger/fabric-contract-api-go/contractapi"

func (s *QueryContract) LogQuery(ctx TransactionContextInterface, query string) error {
	user := ctx.GetData()
	err := ctx.GetStub().PutState(user, []byte(query))
	return err
}

func (s *QueryContract) GetUserHistory(ctx TransactionContextInterface, user string) ([]string, error) {
	resultIterator, err := ctx.GetStub().GetHistoryForKey(user)
	if err != nil {
		return nil, err
	}
	defer resultIterator.Close()

	var history []string
	for resultIterator.HasNext() {
		queryResponse, err := resultIterator.Next()
		if err != nil {
			return nil, err
		}
		history = append(history, string(queryResponse.Value))
	}

	return history, nil
}
