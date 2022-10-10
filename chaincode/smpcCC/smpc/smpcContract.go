package smpc

import (
	"log"
	"fmt"
	"encoding/json"
	"encoding/hex"
    "crypto/sha256"

	contractapi "github.com/hyperledger/fabric-contract-api-go/contractapi"
	"github.com/hyperledger/fabric-chaincode-go/pkg/cid"
)

// SMPC Smart Contract
type RequestRouter struct {
	contractapi.Contract
}

// SMPC Query type
type Request struct {
	// Type
	ObjectType string `json:"type"`

	// Data
	RequestID 	string 		`json:"requestID"`
	MpcIDs 	  	[]string 	`json:"mpcIDs"`  
	DatasetIDs	[]string  	`json:"datasetIDs"`
	Function    string 		`json:"functionID"`
	Status 		string 		`json:"status"`
	Timestamp 	int64    	`json:"timestamp"`
}

// Request Object Type
var REQUEST_OBJECT_TYPE = "request"
var EMPTY_STR = ""

// Create Request State
func (s *RequestRouter) CreateRequest(ctx contractapi.TransactionContextInterface, requestString string) (string, error) {
	method := "CreateRequest";
	log.Printf("%s - start\n", method);

	err := assertAuthorised(ctx);
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s - ", method, err)
	}

	request, err := s.getRequestFromString(requestString);
	if err != nil {
		return EMPTY_STR, err
	}

	request.ObjectType = REQUEST_OBJECT_TYPE

	// Timestamp in Unix Nanoseconds
	timestamp, err := ctx.GetStub().GetTxTimestamp()
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s - Error getting timestamp", method)
	}

	request.Timestamp = timestamp.Seconds

	// Hash the request to get ID
	reqID, err := hash(request)
	if err != nil {
		return EMPTY_STR, fmt.Errorf("%s - Error hashing request", method)
	}

	request.RequestID = reqID

	// Interface -> bytes
	requestBytes, err := json.Marshal(request)
	if err != nil {
		return EMPTY_STR, err
	}

	// Store Request in ledger
	key, _ := ctx.GetStub().CreateCompositeKey(REQUEST_OBJECT_TYPE, []string{request.RequestID})
	err = ctx.GetStub().PutState(key, requestBytes)
	if err != nil {
		return EMPTY_STR, err
	}

	ctx.GetStub().SetEvent("CreateRequest", requestBytes)
	return reqID, nil
}

// Fetch all Requests
func (s *RequestRouter) GetRequests(ctx contractapi.TransactionContextInterface) ([]*Request, error) {
	resultsIterator, err := ctx.GetStub().GetStateByPartialCompositeKey(REQUEST_OBJECT_TYPE, nil)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	var requests []*Request
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var request *Request
		err = json.Unmarshal(queryResponse.Value, &request)
		if err != nil {
			return nil, err
		}

		requests = append(requests, request)
	}

	return requests, nil
}

func assertAuthorised(ctx contractapi.TransactionContextInterface) (error) {

	// Check if caller is a client 
	role := "client"
	hasOuValue, err := cid.HasOUValue(ctx.GetStub(), role)
	if err != nil {
		return err
	}

	if !hasOuValue {
		return fmt.Errorf("OU value is not %s", role)
	}

	// Check if caller belongs to the Organization as a non User
	mspID, err := ctx.GetClientIdentity().GetMSPID();
	if err != nil {
		return err
	}

	if mspID != "LynkeusMSP" && mspID != "TexMSP" {
		return fmt.Errorf("Not authorized to Create SMPC Requests");
	}

	return nil
}

// Hash an interface
func hash(o interface{}) (string, error) {

	bytes, err := json.Marshal(o)
	if err != nil {
		return "", err
	}

	hashBytes := sha256.Sum256(bytes)
	return hex.EncodeToString(hashBytes[:]), nil
}

// Get Request Interface from JSON Rich String
func (s *RequestRouter) getRequestFromString(requestString string) (*Request, error) {
	method := "getRequestFromString";

	var request *Request
	err := json.Unmarshal([]byte(requestString), &request)
	if err != nil {
		return nil, err
	}

	log.Printf("%s - Request:\n %v", method, request);
	return request, nil
}