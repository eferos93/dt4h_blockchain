package dt4h

import (
	"encoding/json"
	"fmt"
	"log"
)

// ============================================================================
// Privacy Budget Contract – manages differential-privacy epsilon budgets
// ============================================================================

// ---------------------------------------------------------------------------
// Ledger key helpers
// ---------------------------------------------------------------------------

// budgetKey returns the primary composite key for a (user, dataset) budget.
func budgetKey(ctx TransactionContextInterface, userID, datasetID string) (string, error) {
	return ctx.GetStub().CreateCompositeKey(PRIVACY_BUDGET_OBJECT_TYPE, []string{userID, datasetID})
}

// budgetIndexKeys creates the secondary index keys that allow efficient
// range-queries by user or by dataset.
func budgetIndexKeys(ctx TransactionContextInterface, userID, datasetID string) (byUser string, byDataset string, err error) {
	byUser, err = ctx.GetStub().CreateCompositeKey(INDEX_BUDGET_BY_USER, []string{userID, datasetID})
	if err != nil {
		return
	}
	byDataset, err = ctx.GetStub().CreateCompositeKey(INDEX_BUDGET_BY_DATASET, []string{datasetID, userID})
	return
}

// logKey returns the composite key for a single consumption-log entry.
func logKey(ctx TransactionContextInterface, userID, datasetID, txID string) (string, error) {
	return ctx.GetStub().CreateCompositeKey(BUDGET_LOG_OBJECT_TYPE, []string{userID, datasetID, txID})
}

// logIndexKeys creates the secondary index keys for consumption logs.
func logIndexKeys(ctx TransactionContextInterface, userID, datasetID, txID string) (byUser string, byDataset string, err error) {
	byUser, err = ctx.GetStub().CreateCompositeKey(INDEX_LOG_BY_USER, []string{userID, datasetID, txID})
	if err != nil {
		return
	}
	byDataset, err = ctx.GetStub().CreateCompositeKey(INDEX_LOG_BY_DATASET, []string{datasetID, userID, txID})
	return
}

// ---------------------------------------------------------------------------
// Write operations
// ---------------------------------------------------------------------------

// InitializeBudget creates a new privacy budget for a (user, dataset) pair.
// It fails if a budget already exists for that pair.
//
// Parameters:
//   - userID:       the identity of the user who will consume the budget
//   - datasetID:    the identifier of the dataset
//   - totalEpsilon: the maximum epsilon the user is allowed to spend
func (s *PrivacyBudgetContract) InitializeBudget(
	ctx TransactionContextInterface,
	userID string,
	datasetID string,
	totalEpsilon float64,
) (*PrivacyBudget, error) {
	method := "InitializeBudget"

	if err := assertAuthorizedMSP(ctx); err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	if totalEpsilon <= 0 {
		return nil, fmt.Errorf("%s: totalEpsilon must be > 0, got %f", method, totalEpsilon)
	}

	key, err := budgetKey(ctx, userID, datasetID)
	if err != nil {
		return nil, fmt.Errorf("%s: key error: %v", method, err)
	}

	// Prevent overwriting an existing budget.
	existing, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, fmt.Errorf("%s: ledger read error: %v", method, err)
	}
	if existing != nil {
		return nil, fmt.Errorf("%s: budget already exists for user=%s dataset=%s", method, userID, datasetID)
	}

	now := nowUTC()
	budget := &PrivacyBudget{
		ObjectType:     PRIVACY_BUDGET_OBJECT_TYPE,
		UserID:         userID,
		DatasetID:      datasetID,
		TotalBudget:    totalEpsilon,
		ConsumedBudget: 0,
		Status:         BUDGET_ACTIVE,
		CreatedAt:      now,
		UpdatedAt:      now,
	}

	data, err := json.Marshal(budget)
	if err != nil {
		return nil, fmt.Errorf("%s: marshal error: %v", method, err)
	}
	if err := ctx.GetStub().PutState(key, data); err != nil {
		return nil, fmt.Errorf("%s: put error: %v", method, err)
	}

	// Write index entries (value is empty – they just point to the primary key).
	byUser, byDataset, err := budgetIndexKeys(ctx, userID, datasetID)
	if err != nil {
		return nil, fmt.Errorf("%s: index key error: %v", method, err)
	}
	if err := ctx.GetStub().PutState(byUser, []byte{0x00}); err != nil {
		return nil, fmt.Errorf("%s: index put error: %v", method, err)
	}
	if err := ctx.GetStub().PutState(byDataset, []byte{0x00}); err != nil {
		return nil, fmt.Errorf("%s: index put error: %v", method, err)
	}

	log.Printf("%s: created budget user=%s dataset=%s epsilon=%f", method, userID, datasetID, totalEpsilon)
	return budget, nil
}

// ConsumeBudget deducts epsilon from an existing budget and writes an
// immutable consumption-log entry. The transaction is rejected when:
//   - the budget does not exist or is not Active
//   - the remaining budget is insufficient
//
// Returns the updated PrivacyBudget.
func (s *PrivacyBudgetContract) ConsumeBudget(
	ctx TransactionContextInterface,
	userID string,
	datasetID string,
	epsilonUsed float64,
	queryBody string,
) (*PrivacyBudget, error) {
	method := "ConsumeBudget"

	if epsilonUsed <= 0 {
		return nil, fmt.Errorf("%s: epsilonUsed must be > 0, got %f", method, epsilonUsed)
	}

	// ---------- read current budget ----------
	budget, key, err := s.readBudget(ctx, userID, datasetID)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	if budget.Status != BUDGET_ACTIVE {
		return nil, fmt.Errorf("%s: budget is %s for user=%s dataset=%s", method, budget.Status, userID, datasetID)
	}
	if !budget.CanConsume(epsilonUsed) {
		return nil, fmt.Errorf(
			"%s: insufficient budget for user=%s dataset=%s: requested=%f remaining=%f",
			method, userID, datasetID, epsilonUsed, budget.RemainingBudget(),
		)
	}

	// ---------- update budget ----------
	budget.ConsumedBudget += epsilonUsed
	budget.UpdatedAt = nowUTC()
	if budget.RemainingBudget() <= 0 {
		budget.Status = BUDGET_EXHAUSTED
	}

	data, err := json.Marshal(budget)
	if err != nil {
		return nil, fmt.Errorf("%s: marshal error: %v", method, err)
	}
	if err := ctx.GetStub().PutState(key, data); err != nil {
		return nil, fmt.Errorf("%s: put error: %v", method, err)
	}

	// ---------- write consumption log ----------
	txID := ctx.GetStub().GetTxID()
	logEntry := &BudgetConsumptionLog{
		ObjectType:        BUDGET_LOG_OBJECT_TYPE,
		UserID:            userID,
		DatasetID:         datasetID,
		QueryBody:         queryBody,
		EpsilonUsed:       epsilonUsed,
		CumulativeEpsilon: budget.ConsumedBudget,
		RemainingEpsilon:  budget.RemainingBudget(),
		TxID:              txID,
		Timestamp:         budget.UpdatedAt,
	}

	if err := s.writeLog(ctx, logEntry); err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	log.Printf("%s: consumed ε=%f  user=%s dataset=%s  remaining=%f",
		method, epsilonUsed, userID, datasetID, budget.RemainingBudget())
	return budget, nil
}

// UpdateBudget changes the total epsilon for an existing budget.
// Only increases are allowed (you cannot reduce below what was already consumed).
func (s *PrivacyBudgetContract) UpdateBudget(
	ctx TransactionContextInterface,
	userID string,
	datasetID string,
	newTotalEpsilon float64,
) (*PrivacyBudget, error) {
	method := "UpdateBudget"

	if err := assertAuthorizedMSP(ctx); err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	budget, key, err := s.readBudget(ctx, userID, datasetID)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	if newTotalEpsilon < budget.ConsumedBudget {
		return nil, fmt.Errorf(
			"%s: new total %f is less than already consumed %f",
			method, newTotalEpsilon, budget.ConsumedBudget,
		)
	}

	budget.TotalBudget = newTotalEpsilon
	budget.UpdatedAt = nowUTC()
	if budget.Status == BUDGET_EXHAUSTED && budget.RemainingBudget() > 0 {
		budget.Status = BUDGET_ACTIVE
	}

	data, err := json.Marshal(budget)
	if err != nil {
		return nil, fmt.Errorf("%s: marshal error: %v", method, err)
	}
	if err := ctx.GetStub().PutState(key, data); err != nil {
		return nil, fmt.Errorf("%s: put error: %v", method, err)
	}

	log.Printf("%s: updated budget user=%s dataset=%s newTotal=%f", method, userID, datasetID, newTotalEpsilon)
	return budget, nil
}

// RevokeBudget marks a budget as Revoked so no further queries can consume it.
func (s *PrivacyBudgetContract) RevokeBudget(
	ctx TransactionContextInterface,
	userID string,
	datasetID string,
) error {
	method := "RevokeBudget"

	if err := assertAuthorizedMSP(ctx); err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	budget, key, err := s.readBudget(ctx, userID, datasetID)
	if err != nil {
		return fmt.Errorf("%s: %v", method, err)
	}

	budget.Status = BUDGET_REVOKED
	budget.UpdatedAt = nowUTC()

	data, err := json.Marshal(budget)
	if err != nil {
		return fmt.Errorf("%s: marshal error: %v", method, err)
	}
	if err := ctx.GetStub().PutState(key, data); err != nil {
		return fmt.Errorf("%s: put error: %v", method, err)
	}

	log.Printf("%s: revoked budget user=%s dataset=%s", method, userID, datasetID)
	return nil
}

// ---------------------------------------------------------------------------
// Read / query operations
// ---------------------------------------------------------------------------

// GetBudget returns the current PrivacyBudget for a (user, dataset) pair.
func (s *PrivacyBudgetContract) GetBudget(
	ctx TransactionContextInterface,
	userID string,
	datasetID string,
) (*PrivacyBudget, error) {
	budget, _, err := s.readBudget(ctx, userID, datasetID)
	return budget, err
}

// GetRemainingBudget is a convenience function returning just the remaining ε.
func (s *PrivacyBudgetContract) GetRemainingBudget(
	ctx TransactionContextInterface,
	userID string,
	datasetID string,
) (float64, error) {
	budget, _, err := s.readBudget(ctx, userID, datasetID)
	if err != nil {
		return 0, err
	}
	return budget.RemainingBudget(), nil
}

// GetBudgetsByUser returns all budgets belonging to a given user.
func (s *PrivacyBudgetContract) GetBudgetsByUser(
	ctx TransactionContextInterface,
	userID string,
) ([]*PrivacyBudget, error) {
	return s.queryBudgetsByIndex(ctx, INDEX_BUDGET_BY_USER, userID)
}

// GetBudgetsByDataset returns all budgets associated with a given dataset.
func (s *PrivacyBudgetContract) GetBudgetsByDataset(
	ctx TransactionContextInterface,
	datasetID string,
) ([]*PrivacyBudget, error) {
	return s.queryBudgetsByIndex(ctx, INDEX_BUDGET_BY_DATASET, datasetID)
}

// GetBudgetHistory returns the full modification history of a budget from
// the ledger's block history.
func (s *PrivacyBudgetContract) GetBudgetHistory(
	ctx TransactionContextInterface,
	userID string,
	datasetID string,
) ([]*PrivacyBudget, error) {
	method := "GetBudgetHistory"

	key, err := budgetKey(ctx, userID, datasetID)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	iter, err := ctx.GetStub().GetHistoryForKey(key)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer iter.Close()

	var history []*PrivacyBudget
	for iter.HasNext() {
		mod, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: iterator error: %v", method, err)
		}
		if mod.IsDelete {
			continue
		}
		var b PrivacyBudget
		if err := json.Unmarshal(mod.Value, &b); err != nil {
			return nil, fmt.Errorf("%s: unmarshal error: %v", method, err)
		}
		history = append(history, &b)
	}
	return history, nil
}

// GetConsumptionLogs returns all consumption log entries for a (user, dataset)
// pair, ordered by transaction history.
func (s *PrivacyBudgetContract) GetConsumptionLogs(
	ctx TransactionContextInterface,
	userID string,
	datasetID string,
) ([]*BudgetConsumptionLog, error) {
	method := "GetConsumptionLogs"

	iter, err := ctx.GetStub().GetStateByPartialCompositeKey(
		BUDGET_LOG_OBJECT_TYPE, []string{userID, datasetID},
	)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer iter.Close()

	var logs []*BudgetConsumptionLog
	for iter.HasNext() {
		kv, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: iterator error: %v", method, err)
		}
		var entry BudgetConsumptionLog
		if err := json.Unmarshal(kv.Value, &entry); err != nil {
			return nil, fmt.Errorf("%s: unmarshal error: %v", method, err)
		}
		logs = append(logs, &entry)
	}
	return logs, nil
}

// GetConsumptionLogsByUser returns all consumption logs for a given user
// across all datasets.
func (s *PrivacyBudgetContract) GetConsumptionLogsByUser(
	ctx TransactionContextInterface,
	userID string,
) ([]*BudgetConsumptionLog, error) {
	method := "GetConsumptionLogsByUser"

	iter, err := ctx.GetStub().GetStateByPartialCompositeKey(
		INDEX_LOG_BY_USER, []string{userID},
	)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer iter.Close()

	var logs []*BudgetConsumptionLog
	for iter.HasNext() {
		kv, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: iterator error: %v", method, err)
		}
		// Index entries store only a pointer byte; extract the attributes
		// from the composite key and fetch the actual log.
		_, parts, err := ctx.GetStub().SplitCompositeKey(kv.Key)
		if err != nil || len(parts) < 3 {
			continue
		}
		entryUserID, entryDatasetID, entryTxID := parts[0], parts[1], parts[2]
		lk, err := logKey(ctx, entryUserID, entryDatasetID, entryTxID)
		if err != nil {
			continue
		}
		raw, err := ctx.GetStub().GetState(lk)
		if err != nil || raw == nil {
			continue
		}
		var entry BudgetConsumptionLog
		if err := json.Unmarshal(raw, &entry); err != nil {
			continue
		}
		logs = append(logs, &entry)
	}
	return logs, nil
}

// GetConsumptionLogsByDataset returns all consumption logs for a given dataset
// across all users.
func (s *PrivacyBudgetContract) GetConsumptionLogsByDataset(
	ctx TransactionContextInterface,
	datasetID string,
) ([]*BudgetConsumptionLog, error) {
	method := "GetConsumptionLogsByDataset"

	iter, err := ctx.GetStub().GetStateByPartialCompositeKey(
		INDEX_LOG_BY_DATASET, []string{datasetID},
	)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}
	defer iter.Close()

	var logs []*BudgetConsumptionLog
	for iter.HasNext() {
		kv, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("%s: iterator error: %v", method, err)
		}
		_, parts, err := ctx.GetStub().SplitCompositeKey(kv.Key)
		if err != nil || len(parts) < 3 {
			continue
		}
		entryDatasetID, entryUserID, entryTxID := parts[0], parts[1], parts[2]
		lk, err := logKey(ctx, entryUserID, entryDatasetID, entryTxID)
		if err != nil {
			continue
		}
		raw, err := ctx.GetStub().GetState(lk)
		if err != nil || raw == nil {
			continue
		}
		var entry BudgetConsumptionLog
		if err := json.Unmarshal(raw, &entry); err != nil {
			continue
		}
		logs = append(logs, &entry)
	}
	return logs, nil
}

// GetBudgetSummary returns a high-level summary including query count.
func (s *PrivacyBudgetContract) GetBudgetSummary(
	ctx TransactionContextInterface,
	userID string,
	datasetID string,
) (*BudgetSummary, error) {
	method := "GetBudgetSummary"

	budget, _, err := s.readBudget(ctx, userID, datasetID)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	logs, err := s.GetConsumptionLogs(ctx, userID, datasetID)
	if err != nil {
		return nil, fmt.Errorf("%s: %v", method, err)
	}

	return &BudgetSummary{
		UserID:          userID,
		DatasetID:       datasetID,
		TotalBudget:     budget.TotalBudget,
		ConsumedBudget:  budget.ConsumedBudget,
		RemainingBudget: budget.RemainingBudget(),
		Status:          budget.Status,
		QueryCount:      len(logs),
	}, nil
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

// readBudget fetches and unmarshals a PrivacyBudget from the ledger.
func (s *PrivacyBudgetContract) readBudget(
	ctx TransactionContextInterface,
	userID, datasetID string,
) (*PrivacyBudget, string, error) {
	key, err := budgetKey(ctx, userID, datasetID)
	if err != nil {
		return nil, "", fmt.Errorf("readBudget: key error: %v", err)
	}

	raw, err := ctx.GetStub().GetState(key)
	if err != nil {
		return nil, "", fmt.Errorf("readBudget: ledger read error: %v", err)
	}
	if raw == nil {
		return nil, "", fmt.Errorf("readBudget: no budget found for user=%s dataset=%s", userID, datasetID)
	}

	var budget PrivacyBudget
	if err := json.Unmarshal(raw, &budget); err != nil {
		return nil, "", fmt.Errorf("readBudget: unmarshal error: %v", err)
	}
	return &budget, key, nil
}

// writeLog persists a BudgetConsumptionLog entry and its index keys.
func (s *PrivacyBudgetContract) writeLog(
	ctx TransactionContextInterface,
	entry *BudgetConsumptionLog,
) error {
	lk, err := logKey(ctx, entry.UserID, entry.DatasetID, entry.TxID)
	if err != nil {
		return fmt.Errorf("writeLog: key error: %v", err)
	}

	data, err := json.Marshal(entry)
	if err != nil {
		return fmt.Errorf("writeLog: marshal error: %v", err)
	}
	if err := ctx.GetStub().PutState(lk, data); err != nil {
		return fmt.Errorf("writeLog: put error: %v", err)
	}

	byUser, byDataset, err := logIndexKeys(ctx, entry.UserID, entry.DatasetID, entry.TxID)
	if err != nil {
		return fmt.Errorf("writeLog: index key error: %v", err)
	}
	if err := ctx.GetStub().PutState(byUser, []byte{0x00}); err != nil {
		return fmt.Errorf("writeLog: index put error: %v", err)
	}
	if err := ctx.GetStub().PutState(byDataset, []byte{0x00}); err != nil {
		return fmt.Errorf("writeLog: index put error: %v", err)
	}
	return nil
}

// queryBudgetsByIndex performs a partial-composite-key range scan on the
// given index name with a single leading attribute and returns all matching
// PrivacyBudget objects.
func (s *PrivacyBudgetContract) queryBudgetsByIndex(
	ctx TransactionContextInterface,
	indexName string,
	leadingAttr string,
) ([]*PrivacyBudget, error) {
	iter, err := ctx.GetStub().GetStateByPartialCompositeKey(indexName, []string{leadingAttr})
	if err != nil {
		return nil, fmt.Errorf("queryBudgetsByIndex: %v", err)
	}
	defer iter.Close()

	var results []*PrivacyBudget
	for iter.HasNext() {
		kv, err := iter.Next()
		if err != nil {
			return nil, fmt.Errorf("queryBudgetsByIndex: iterator error: %v", err)
		}

		_, parts, err := ctx.GetStub().SplitCompositeKey(kv.Key)
		if err != nil || len(parts) < 2 {
			continue
		}

		// Determine userID / datasetID from the index shape.
		var uid, did string
		if indexName == INDEX_BUDGET_BY_USER {
			uid, did = parts[0], parts[1]
		} else {
			did, uid = parts[0], parts[1]
		}

		budget, _, err := s.readBudget(ctx, uid, did)
		if err != nil {
			continue
		}
		results = append(results, budget)
	}
	return results, nil
}
