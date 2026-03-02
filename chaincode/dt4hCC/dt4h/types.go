package dt4h

import (
	"fmt"
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"
)

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const EMPTY_STR = ""

// Object type prefixes used as composite-key namespaces on the ledger.
const (
	PRIVACY_BUDGET_OBJECT_TYPE = "privacyBudget"
	BUDGET_LOG_OBJECT_TYPE     = "budgetLog"
	QUERY_LOG_OBJECT_TYPE      = "queryLog"
)

// Composite-key index names for range queries.
const (
	INDEX_BUDGET_BY_USER    = "budget~user~dataset"
	INDEX_BUDGET_BY_DATASET = "budget~dataset~user"
	INDEX_LOG_BY_USER       = "log~user~dataset~txid"
	INDEX_LOG_BY_DATASET    = "log~dataset~user~txid"
)

// Budget status values.
const (
	BUDGET_ACTIVE    = "Active"
	BUDGET_EXHAUSTED = "Exhausted"
	BUDGET_REVOKED   = "Revoked"
)

var AUTHORIZED_MSPS = []string{"UbMSP", "AthenapeersMSP", "BscMSP"}

// ---------------------------------------------------------------------------
// Contract types
// ---------------------------------------------------------------------------

// QueryContract handles query logging and user query history.
type QueryContract struct {
	contractapi.Contract
}

// PrivacyBudgetContract manages differential-privacy epsilon budgets
// across users and datasets.
type PrivacyBudgetContract struct {
	contractapi.Contract
}

// ---------------------------------------------------------------------------
// Domain types – Query tracking
// ---------------------------------------------------------------------------

// Query represents a single logged query with its epsilon cost.
type Query struct {
	QueryBody   string  `json:"queryBody"`
	DatasetID   string  `json:"datasetId"`
	EpsilonUsed float64 `json:"epsilonUsed"`
	Timestamp   string  `json:"timestamp"`
	TxID        string  `json:"txId"`
}

// UserHistory is the full query history for a given user.
type UserHistory struct {
	UserID  string  `json:"userId"`
	Queries []Query `json:"queries"`
}

// ---------------------------------------------------------------------------
// Domain types – Privacy Budget
// ---------------------------------------------------------------------------

// PrivacyBudget tracks the total and consumed epsilon for a (user, dataset) pair.
type PrivacyBudget struct {
	ObjectType     string  `json:"type"`
	UserID         string  `json:"userId"`
	DatasetID      string  `json:"datasetId"`
	TotalBudget    float64 `json:"totalBudget"`    // maximum epsilon allowed
	ConsumedBudget float64 `json:"consumedBudget"` // epsilon spent so far
	Status         string  `json:"status"`         // Active | Exhausted | Revoked
	CreatedAt      string  `json:"createdAt"`
	UpdatedAt      string  `json:"updatedAt"`
}

// RemainingBudget returns the epsilon still available.
func (pb *PrivacyBudget) RemainingBudget() float64 {
	return pb.TotalBudget - pb.ConsumedBudget
}

// CanConsume checks whether the budget has enough epsilon left.
func (pb *PrivacyBudget) CanConsume(epsilon float64) bool {
	return pb.Status == BUDGET_ACTIVE && pb.RemainingBudget() >= epsilon
}

// BudgetConsumptionLog is an immutable audit-trail entry written every time
// epsilon is deducted from a budget.
type BudgetConsumptionLog struct {
	ObjectType  string  `json:"type"`
	UserID      string  `json:"userId"`
	DatasetID   string  `json:"datasetId"`
	QueryBody   string  `json:"queryBody"`
	EpsilonUsed float64 `json:"epsilonUsed"`
	// Cumulative consumed budget *after* this deduction.
	CumulativeEpsilon float64 `json:"cumulativeEpsilon"`
	RemainingEpsilon  float64 `json:"remainingEpsilon"`
	TxID              string  `json:"txId"`
	Timestamp         string  `json:"timestamp"`
}

// BudgetSummary is a convenience view returned by query functions.
type BudgetSummary struct {
	UserID          string  `json:"userId"`
	DatasetID       string  `json:"datasetId"`
	TotalBudget     float64 `json:"totalBudget"`
	ConsumedBudget  float64 `json:"consumedBudget"`
	RemainingBudget float64 `json:"remainingBudget"`
	Status          string  `json:"status"`
	QueryCount      int     `json:"queryCount"`
}

// ---------------------------------------------------------------------------
// Error helper
// ---------------------------------------------------------------------------

// Error is a typed error with a numeric code.
type Error struct {
	Code int
	Err  error
}

func (e *Error) Error() string {
	return fmt.Sprintf("Error code: %d: %s", e.Code, e.Err)
}

// ---------------------------------------------------------------------------
// Time helper
// ---------------------------------------------------------------------------

// nowUTC returns the current UTC time formatted as RFC3339.
func nowUTC() string {
	return time.Now().UTC().Format(time.RFC3339)
}
