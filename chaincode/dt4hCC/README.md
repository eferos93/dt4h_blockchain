# DT4H Chaincode – Differential Privacy Budget Tracker

Hyperledger Fabric chaincode that tracks **differential-privacy (DP) epsilon budgets** across users and datasets. Every query that touches a dataset consumes a configurable amount of epsilon (ε). The chaincode enforces budget limits on-chain so that no user can exceed the privacy guarantee assigned to them for a given dataset.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Project Structure](#project-structure)
4. [Data Model](#data-model)
5. [Smart Contracts](#smart-contracts)
   - [PrivacyBudgetContract](#privacybudgetcontract)
   - [QueryContract](#querycontract)
6. [Ledger Key Design](#ledger-key-design)
7. [Lifecycle & State Transitions](#lifecycle--state-transitions)
8. [Authorization](#authorization)
9. [Building](#building)
10. [Deployment](#deployment)
11. [Usage Examples](#usage-examples)

---

## Overview

In differential privacy, every query against a dataset "costs" a measurable amount of privacy loss expressed as **epsilon (ε)**. To prevent unbounded information leakage, each user is assigned a **privacy budget** per dataset. Once the budget is exhausted, no further queries are allowed.

This chaincode provides:

- **Budget management** – initialize, update, and revoke per-user-per-dataset ε budgets.
- **Atomic consumption** – every logged query atomically deducts ε and creates an immutable audit-trail entry in a single transaction.
- **Rich queries** – look up budgets and consumption logs by user, by dataset, or by (user, dataset) pair.
- **Full history** – retrieve the complete ledger history showing every state change of a budget over time.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│                      Fabric Peer                         │
│  ┌────────────────────────────────────────────────────┐  │
│  │                   dt4hCC Chaincode                 │  │
│  │                                                    │  │
│  │  ┌──────────────────┐  ┌────────────────────────┐  │  │
│  │  │  QueryContract   │  │ PrivacyBudgetContract  │  │  │
│  │  │                  │  │                        │  │  │
│  │  │  • LogQuery      │  │  • InitializeBudget    │  │  │
│  │  │  • GetUserHistory│  │  • ConsumeBudget       │  │  │
│  │  │  • GetMyHistory  │  │  • UpdateBudget        │  │  │
│  │  │                  │  │  • RevokeBudget        │  │  │
│  │  │                  │  │  • GetBudget           │  │  │
│  │  │   calls ──────────────► GetRemainingBudget   │  │  │
│  │  │   ConsumeBudget  │  │  • GetBudgetsByUser    │  │  │
│  │  │                  │  │  • GetBudgetsByDataset  │  │  │
│  │  │                  │  │  • GetBudgetHistory    │  │  │
│  │  │                  │  │  • GetConsumptionLogs  │  │  │
│  │  │                  │  │  • GetBudgetSummary    │  │  │
│  │  └──────────────────┘  └────────────────────────┘  │  │
│  │                                                    │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │          TransactionContext                   │  │  │
│  │  │  (BeforeTransaction extracts userID + mspID) │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
│                          │                               │
│               ┌──────────▼──────────┐                    │
│               │   World State (DB)  │                    │
│               │  CouchDB / LevelDB  │                    │
│               └─────────────────────┘                    │
└──────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
dt4hCC/
├── main.go                          # Chaincode entry point – registers contracts
├── go.mod                           # Go module definition
├── go.sum                           # Dependency checksums
├── README.md                        # This file
├── META-INF/                        # Fabric chaincode metadata
└── dt4h/
    ├── types.go                     # Domain types, constants, and helpers
    ├── transaction_context.go       # Custom TransactionContext with identity fields
    ├── utils.go                     # BeforeTransaction hook & MSP authorization
    ├── privacy_budget_contract.go   # PrivacyBudgetContract implementation
    └── query_contract.go            # QueryContract implementation
```

---

## Data Model

### PrivacyBudget

Stored on-ledger under composite key `privacyBudget\0{userID}\0{datasetID}`.

| Field            | Type    | Description                                    |
|------------------|---------|------------------------------------------------|
| `type`           | string  | Always `"privacyBudget"`                       |
| `userId`         | string  | X.509 identity of the user                     |
| `datasetId`      | string  | Identifier of the dataset                      |
| `totalBudget`    | float64 | Maximum ε allowed                              |
| `consumedBudget` | float64 | ε spent so far                                 |
| `status`         | string  | `Active` / `Exhausted` / `Revoked`             |
| `createdAt`      | string  | RFC 3339 timestamp                             |
| `updatedAt`      | string  | RFC 3339 timestamp                             |

### BudgetConsumptionLog

Stored on-ledger under composite key `budgetLog\0{userID}\0{datasetID}\0{txID}`.

| Field               | Type    | Description                                    |
|----------------------|---------|-----------------------------------------------|
| `type`              | string  | Always `"budgetLog"`                           |
| `userId`            | string  | User who consumed                              |
| `datasetId`         | string  | Dataset queried                                |
| `queryBody`         | string  | The query text (for auditing)                  |
| `epsilonUsed`       | float64 | ε deducted in this transaction                 |
| `cumulativeEpsilon` | float64 | Total ε consumed *after* this deduction        |
| `remainingEpsilon`  | float64 | ε remaining *after* this deduction             |
| `txId`              | string  | Fabric transaction ID                          |
| `timestamp`         | string  | RFC 3339 timestamp                             |

### Query

Stored on-ledger under composite key `queryLog\0{userID}\0{txID}`.

| Field         | Type    | Description                            |
|---------------|---------|----------------------------------------|
| `queryBody`   | string  | The query text                         |
| `datasetId`   | string  | Dataset queried                        |
| `epsilonUsed` | float64 | ε cost of this query                   |
| `timestamp`   | string  | RFC 3339 timestamp                     |
| `txId`        | string  | Fabric transaction ID                  |

### BudgetSummary (read-only, not persisted)

| Field             | Type    | Description                            |
|-------------------|---------|----------------------------------------|
| `userId`          | string  | User identity                          |
| `datasetId`       | string  | Dataset identity                       |
| `totalBudget`     | float64 | Maximum ε                              |
| `consumedBudget`  | float64 | ε spent                                |
| `remainingBudget` | float64 | ε available                            |
| `status`          | string  | Budget status                          |
| `queryCount`      | int     | Number of queries executed             |

---

## Smart Contracts

### PrivacyBudgetContract

Manages the full lifecycle of differential-privacy budgets.

#### Write Operations

| Function | Parameters | Description |
|----------|-----------|-------------|
| `InitializeBudget` | `userID`, `datasetID`, `totalEpsilon` | Create a new budget. Fails if one already exists for the pair. **Requires authorized MSP.** |
| `ConsumeBudget` | `userID`, `datasetID`, `epsilonUsed`, `queryBody` | Deduct ε from a budget. Writes an immutable consumption log. Rejects if budget is insufficient or not Active. |
| `UpdateBudget` | `userID`, `datasetID`, `newTotalEpsilon` | Change the total ε cap. Cannot reduce below already-consumed amount. Reactivates an Exhausted budget if new cap allows. **Requires authorized MSP.** |
| `RevokeBudget` | `userID`, `datasetID` | Permanently mark a budget as Revoked. No further consumption is possible. **Requires authorized MSP.** |

#### Read Operations

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `GetBudget` | `userID`, `datasetID` | `PrivacyBudget` | Fetch a single budget |
| `GetRemainingBudget` | `userID`, `datasetID` | `float64` | Remaining ε only |
| `GetBudgetsByUser` | `userID` | `[]PrivacyBudget` | All budgets for a user |
| `GetBudgetsByDataset` | `datasetID` | `[]PrivacyBudget` | All budgets for a dataset |
| `GetBudgetHistory` | `userID`, `datasetID` | `[]PrivacyBudget` | Full ledger history |
| `GetConsumptionLogs` | `userID`, `datasetID` | `[]BudgetConsumptionLog` | All consumption entries for a (user, dataset) pair |
| `GetConsumptionLogsByUser` | `userID` | `[]BudgetConsumptionLog` | All consumption entries across datasets |
| `GetConsumptionLogsByDataset` | `datasetID` | `[]BudgetConsumptionLog` | All consumption entries across users |
| `GetBudgetSummary` | `userID`, `datasetID` | `BudgetSummary` | Aggregated view with query count |

### QueryContract

User-facing contract for logging queries and browsing history.

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `LogQuery` | `datasetID`, `queryBody`, `epsilonUsed` | `BudgetConsumptionLog` | Record a query, atomically deduct ε. Caller identity is derived from the transaction context. |
| `GetUserHistory` | `userID` | `UserHistory` | All queries for any user |
| `GetMyHistory` | *(none)* | `UserHistory` | Convenience: returns the calling user's own history |

---

## Ledger Key Design

The chaincode uses **Fabric composite keys** to enable efficient partial-key range queries without requiring CouchDB rich queries.

### Primary Keys

| Object Type | Key Structure |
|-------------|---------------|
| Privacy Budget | `privacyBudget\0{userID}\0{datasetID}` |
| Consumption Log | `budgetLog\0{userID}\0{datasetID}\0{txID}` |
| Query Log | `queryLog\0{userID}\0{txID}` |

### Secondary Index Keys

These contain only a sentinel byte (`0x00`) as the value. They exist solely to allow partial-composite-key scans, which then do a point-read against the primary key.

| Index Name | Key Structure | Enables |
|------------|---------------|---------|
| `budget~user~dataset` | `{userID}\0{datasetID}` | "Get all budgets for user X" |
| `budget~dataset~user` | `{datasetID}\0{userID}` | "Get all budgets for dataset Y" |
| `log~user~dataset~txid` | `{userID}\0{datasetID}\0{txID}` | "Get all logs for user X" |
| `log~dataset~user~txid` | `{datasetID}\0{userID}\0{txID}` | "Get all logs for dataset Y" |

---

## Lifecycle & State Transitions

```
                    InitializeBudget
                          │
                          ▼
                    ┌───────────┐
          ┌────────│   Active   │◄──────────┐
          │        └─────┬─────┘            │
          │              │                  │
          │   ConsumeBudget            UpdateBudget
          │   (ε hits 0)              (increases cap)
          │              │                  │
          │              ▼                  │
          │        ┌───────────┐            │
          │        │ Exhausted │────────────┘
          │        └───────────┘
          │
    RevokeBudget
          │
          ▼
    ┌───────────┐
    │  Revoked  │  (terminal – no further consumption)
    └───────────┘
```

---

## Authorization

- **`BeforeTransaction`** runs before every chaincode function and extracts the caller's X.509 identity (`userID`) and organization MSP (`mspID`) from the client certificate. These are stored in the `TransactionContext`.
- Administrative functions (`InitializeBudget`, `UpdateBudget`, `RevokeBudget`) check the caller's MSP against the allow-list:

  ```go
  var AUTHORIZED_MSPS = []string{"UbMSP", "AthenaMSP", "BscMSP"}
  ```

- `LogQuery` uses the caller's own identity derived from the context — users cannot log queries on behalf of others.
- `ConsumeBudget` has no MSP gate by itself (it trusts the caller contract), but it is invoked internally by `LogQuery` which uses the authenticated identity.

---

## Building

### Prerequisites

- Go ≥ 1.24
- Hyperledger Fabric binaries and Docker images for your target Fabric version

### Compile

```bash
cd chaincode/dt4hCC
go build ./...
```

### Run Tests (if added)

```bash
cd chaincode/dt4hCC
go test ./dt4h/... -v
```

---

## Deployment

The chaincode is deployed using the standard Fabric lifecycle. Refer to the root [`DEPLOY.md`](../../DEPLOY.md) for network-specific instructions.

```bash
# Package
peer lifecycle chaincode package dt4hCC.tar.gz \
  --path ./chaincode/dt4hCC \
  --lang golang \
  --label dt4hCC_1.0

# Install on peer
peer lifecycle chaincode install dt4hCC.tar.gz

# Approve & commit (repeat per org)
peer lifecycle chaincode approveformyorg ...
peer lifecycle chaincode commit ...
```

---

## Usage Examples

All examples use the `peer chaincode invoke` / `query` CLI. Adapt for your SDK client (Node, Go, Java, etc.).

### 1. Initialize a budget

Assign user `user1` a budget of ε = 10.0 for dataset `dataset-abc`:

```bash
peer chaincode invoke \
  -C mychannel -n dt4hCC \
  -c '{"function":"PrivacyBudgetContract:InitializeBudget","Args":["user1","dataset-abc","10.0"]}'
```

### 2. Log a query (consume budget)

The calling user submits a query that costs ε = 0.5:

```bash
peer chaincode invoke \
  -C mychannel -n dt4hCC \
  -c '{"function":"QueryContract:LogQuery","Args":["dataset-abc","SELECT AVG(age) FROM patients","0.5"]}'
```

Response includes remaining budget, cumulative consumption, and the transaction ID.

### 3. Check remaining budget

```bash
peer chaincode query \
  -C mychannel -n dt4hCC \
  -c '{"function":"PrivacyBudgetContract:GetRemainingBudget","Args":["user1","dataset-abc"]}'
```

### 4. Get budget summary

```bash
peer chaincode query \
  -C mychannel -n dt4hCC \
  -c '{"function":"PrivacyBudgetContract:GetBudgetSummary","Args":["user1","dataset-abc"]}'
```

Returns:
```json
{
  "userId": "user1",
  "datasetId": "dataset-abc",
  "totalBudget": 10.0,
  "consumedBudget": 0.5,
  "remainingBudget": 9.5,
  "status": "Active",
  "queryCount": 1
}
```

### 5. View consumption audit trail

```bash
peer chaincode query \
  -C mychannel -n dt4hCC \
  -c '{"function":"PrivacyBudgetContract:GetConsumptionLogs","Args":["user1","dataset-abc"]}'
```

### 6. View all budgets for a dataset

```bash
peer chaincode query \
  -C mychannel -n dt4hCC \
  -c '{"function":"PrivacyBudgetContract:GetBudgetsByDataset","Args":["dataset-abc"]}'
```

### 7. Get my query history

```bash
peer chaincode query \
  -C mychannel -n dt4hCC \
  -c '{"function":"QueryContract:GetMyHistory","Args":[]}'
```

### 8. Increase a budget

```bash
peer chaincode invoke \
  -C mychannel -n dt4hCC \
  -c '{"function":"PrivacyBudgetContract:UpdateBudget","Args":["user1","dataset-abc","20.0"]}'
```

### 9. Revoke a budget

```bash
peer chaincode invoke \
  -C mychannel -n dt4hCC \
  -c '{"function":"PrivacyBudgetContract:RevokeBudget","Args":["user1","dataset-abc"]}'
```

---

## License

See the repository root for license information.
