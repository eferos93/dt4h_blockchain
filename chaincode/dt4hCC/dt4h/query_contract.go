package dt4h

import (
	"encoding/json"
	"fmt"
	"log"
)

// ============================================================================
// Query Contract – logs queries and integrates with the privacy budget
// ============================================================================

// LogQuery records a query on the ledger, deducting the given epsilon from the
// caller's privacy budget for the specified dataset. The transaction is
// rejected if the remaining budget is insufficient.
//
// Parameters:
//   - datasetID:   the dataset being queried
//   - queryBody:   the query text / description (for auditing)
//   - epsilonUsed: the differential-privacy cost of this query
func (s *QueryContract) LogQuery(
	ctx TransactionContextInterface,
	datasetID string,
	queryBody string,
	epsilonUsed float64,
) (*BudgetConsumptionLog, error) {
	method := "LogQuery"

	userID := ctx.GetUserID()
	if userID == "" {
		return nil, fmt.Errorf("%s: caller identity not set", method)
	}

	// ---------- consume budget ----------
	budgetContract := new(PrivacyBudgetContract)
	budget, err := budgetContract.ConsumeBudget(ctx, userID, datasetID, epsilonUsed, queryBody)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	// ---------- also write a per-user query log for GetUserHistory ----------
	txID := ctx.GetStub().GetTxID()
	q := Query{
		QueryBody:   queryBody,
		DatasetID:   datasetID,
		EpsilonUsed: epsilonUsed,
		Timestamp:   nowUTC(),
		TxID:        txID,
	}
	qBytes, err := json.Marshal(q)
	if err != nil {
		return nil, fmt.Errorf("%s: marshal error: %v", method, err)
	}

	queryKey, err := ctx.GetStub().CreateCompositeKey(QUERY_LOG_OBJECT_TYPE, []string{userID, txID})
	if err != nil {
		return nil, fmt.Errorf("%s: key error: %v", method, err)
	}
	if err := ctx.GetStub().PutState(queryKey, qBytes); err != nil {
		return nil, fmt.Errorf("%s: put error: %v", method, err)
	}

	log.Printf("%s: logged query user=%s dataset=%s ε=%f remaining=%f",
		method, userID, datasetID, epsilonUsed, budget.RemainingBudget())

	// Return the consumption log entry so the caller sees the result.
	return &BudgetConsumptionLog{
		ObjectType:        BUDGET_LOG_OBJECT_TYPE,
		UserID:            userID,
		DatasetID:         datasetID,
		QueryBody:         queryBody,
		EpsilonUsed:       epsilonUsed,
		CumulativeEpsilon: budget.ConsumedBudget,
		RemainingEpsilon:  budget.RemainingBudget(),
		TxID:              txID,
		Timestamp:         q.Timestamp,
	}, nil
}

// GetUserHistory returns all queries logged by the given user across all
// datasets, ordered by ledger insertion.
func (s *QueryContract) GetUserHistory(
	ctx TransactionContextInterface,
	userID string,
) (*UserHistory, error) {
	method := "GetUserHistory"

	iter, err := ctx.GetStub().GetStateByPartialCompositeKey(QUERY_LOG_OBJECT_TYPE, []string{userID})
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer iter.Close()

	var queries []Query
	for iter.HasNext() {
		kv, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: iterator error: %v", method, err)
		}
		var q Query
		if err := json.Unmarshal(kv.Value, &q); err != nil {
			return nil, fmt.Errorf("%s: unmarshal error: %v", method, err)
		}
		queries = append(queries, q)
	}

	return &UserHistory{UserID: userID, Queries: queries}, nil
}

// GetMyHistory is a convenience wrapper that returns the calling user's own
// query history (the userID is taken from the transaction context).
func (s *QueryContract) GetMyHistory(
	ctx TransactionContextInterface,
) (*UserHistory, error) {
	return s.GetUserHistory(ctx, ctx.GetUserID())
}
