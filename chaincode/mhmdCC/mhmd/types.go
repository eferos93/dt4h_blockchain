package mhmd

import (
	"github.com/hyperledger/fabric-contract-api-go/contractapi"
	"time"
	// "log"
	"fmt"
	// "math/big"
	// "github.com/zmap/zcrypto/encoding/asn1"
	// x509 "github.com/zmap/zcrypto/x509"
	// "github.com/zmap/zcrypto/x509/pkix"
)

const TRUE = "true"
const FALSE = "false"
const EMPTY_STR = ""

const (
	ADMIN 	string = "admin"
	PEER 	string = "peer"
	CLIENT 	string = "client"
	ORDERER string = "orderer"
)

const (
	USER_OBJECT_TYPE      = "user"
	USERID_OBJECT_TYPE    = "userID"
	PRODUCT_OBJECT_TYPE   = "product"
	AGREEMENT_OBJECT_TYPE = "agreement"
	INVENTORY_OBJECT_TYPE = "inventory"
	REVOKED_CERT_OBJECT_TYPE = "revoked"
	ORG_OBJECT_TYPE		  = "org"
)

const (
	HEALTH = "Health and wellness"
	EDUCATION = "Education"

	ANALYTICS = "ANALYTICS"
	BATCH = "BATCH"
	STREAMS = "STREAMS"
)

const (
	AUTOMATED_DECISION_MAKING = "automated"
)

var AUTHORIZED_MSPS = []string{"LynkeusMSP", "TexMSP"}
var AGREEMENT_STATUS = []string{"Eligible", "Paid", "Access", "Withdrawn"}
var PURPOSES = []string{"marketing", "publicly_funded_research", "private_research", "managment", "automated", "study_recommendations", "job_offers", "statistical_research"}
var PROTECTIONS = []string{"Anonymization", "Encryption", "SMPC"}
var PRODUCT_SECTOR = []string{HEALTH, EDUCATION}
var PRODUCT_TYPES = []string{BATCH, ANALYTICS, STREAMS}
var EDUCATIONAL_INSTITUTION_TYPES = []string{"hr_agencies", "private_companies", "public_institutions", "public_research_centers", "public_research_institutions"}
var HEALTH_INSTITUTION_TYPES = []string{"publicHospitals", "privateHospitals", "privateResearch", "publicResearch", "governments", "privateCompanies", "other"}
var AUTOMATED_DECISION_MAKING_CONSEQUENCES = []string{"automated_placing", "hiring_assessments", "clinical_risks_assessment", "diagnostic_or_treatment"}

type RevokedCertificate struct {
	ObjectType 	string `json:"type"`
	MspID		string `json:"mspid"`
	// Data 	   	pkix.RevokedCertificate
	SerialNumber   string `json:"serialNumber"`
	RevocationTime time.Time `json:"revocationTime"`
	Key				string	`json:"key"`
}

type Error struct {
	Code int
	Err  error
}

type ManagementContract struct {
	contractapi.Contract
}

// UserContract The contract utilizing user logic
type UserContract struct {
	contractapi.Contract
}

/* Create contract instance */
type AgreementContract struct {
	contractapi.Contract
}

var agreementContract = new(AgreementContract)
var userContract = new(UserContract)
var managementContract = new(ManagementContract)
var dataContract = new(DataContract)

/*{
	username:"user" + i,
	isOrg:true,
	org: {
		instType:"Private Hospital",
		orgName:"Lynkeus",
		dpoFirstName:"Bob",
		dpoLastName:"Bobinson",
		dpoEmail:"Bob@email.com",
		active:true,
	},
	isBuyer:true,
	purposes: purposeArr
}*/

// User Object containing the user credentials
type User struct {
	// ObjectType is used to distinguish different object types in the same chaincode namespace
	ObjectType string `json:"type"`

	// IDs
	ID       string `json:"id"`
	Username string `json:"username"`
	MspID 	 string `json:"mspid"`

	// Org Are you sharing/looking for data on behalf of an organization such as a private company or a research center?
	IsOrg bool `json:"isOrg"`

	// True if the user is a member of the organization and not the admin
	IsMemberOf   string `json:"isMemberOf,omitempty" metadata:",optional"`
	Org   Org  `json:"org,omitempty" metadata:",optional"`

	IsBuyer bool `json:"isBuyer"`

	// As a buyer, preferences to filter the marketplace (not used?)
	Purposes []string `json:"purposes,omitempty" metadata:",optional"`

	// Validity period of user, upon expiration their products are not accessible
	ValidTo time.Time `json:"validTo"`

	// Key of certificate
	CertKey		string	`json:"certKey" metadata:",optional"`

	// Active status
	Active		bool	`json:"active"`
}

type OrgData struct {
	Verified bool `json:"verified"`
	Members	 []string  `json:"members,omitempty" metadata:",optional"`
}

type Org struct {
	// identity and contact details of the controller, and DPO if applicable
	InstType     string `json:"instType"`
	OrgName      string `json:"orgName"`
	Active       bool   `json:"active"`

	// Users transacting on behalf of the organization
	Members		[]string  `json:"members,omitempty" metadata:",optional"`

	// DPOFirstName string `json:"dpoFirstName"`
	// DPOLastName  string `json:"dpoLastName"`
	// Email        string `json:"dpoEmail"`
}

func (o *Org) initOrg() {
	o.InstType = ""
	o.OrgName = ""
	o.Active = false
	o.Members = []string{}
}

func (o Org) validateOrgArgs() error {
	method := "validateOrgArgs"

	INSTITUTIONS := append(HEALTH_INSTITUTION_TYPES, EDUCATIONAL_INSTITUTION_TYPES...)
	if !_in(o.InstType, INSTITUTIONS){
		return fmt.Errorf("%s - Undefined institution value: %s", method, o.InstType)
	}

	if o.OrgName == EMPTY_STR {
		return fmt.Errorf("%s - Missing Organization Name", method)
	}
	if len(o.Members) == 0 {
		o.Members = []string{}
	}
	o.Active = true
	return nil
}

// BuyerParams The buyer's input to validate against product's policy
type BuyerParams struct {
	Purposes []string `json:"purposes"`
}

// DataContract The contract utilizing data logic
type DataContract struct {
	contractapi.Contract
}

// Product Object containing the product's metadata
type Product struct {
	ObjectType string `json:"type"`

	// IDs
	Owner string `json:"owner"`
	ID    string `json:"id"`

	// Product Metadata
	Name  string  `json:"name,omitempty" metadata:",optional"`
	Price float64 `json:"price"`
	Desc  string  `json:"desc,omitempty" metadata:",optional"`

	// Product Sector
	Sector string `json:"sector,omitempty" metadata:",optional"`

	// Batch etc
	ProductType string `json:"productType,omitempty" metadata:",optional"`

	// Policy object
	Policy Policy `json:"policy"`

	// Auto generated inside contract, time of creation
	Timestamp int64 `json:"timestamp"`

	// Status of staked tokens for the validity of the product
	// Escrow string `json:"escrow,omitempty" metadata:",optional"`

	// In case of a curated Data Product
	Curations []string `json:"curations,omitempty" metadata:",optional"`

	// In case of a Data Union
	// ProductIDs []string `json:"productIDs,omitempty" metadata:",optional"`

}

// Policy Object containing the product's policy
type Policy struct {
	// includes personal info of third party
	InclPersonalInfo bool `json:"inclPersonalInfo,omitempty" metadata:",optional"`

	// third party has granted consent to include personal info
	HasConsent bool `json:"hasConsent,omitempty" metadata:",optional"`

	// marketing, publicly funded research, private research, business to improve their services, automated decision-making (including profiling)
	Purposes []string `json:"purposes"`

	// Anonymization. Encryption. SMPC (these are the values stored on the Blockchain and cache)
	ProtectionType string `json:"protectionType,omitempty" metadata:",optional"`

	//
	SecUseConsent bool   `json:"secondUseConsent,omitempty" metadata:",optional"`
	RecipientType []string `json:"recipientType,omitempty" metadata:",optional"`

	// third country transfers, if any
	TransferToCountry string `json:"transferToCountry,omitempty" metadata:",optional"`

	// time period of the product being available
	StoragePeriod int64 `json:"storagePeriod,omitempty" metadata:",optional"`

	// Org Preapproval
	ApprovedOrgs []string `json:"approvedOrgs,omitempty" metadata:",optional"`

	// User Preapproval
	ApprovedUsers []string `json:"approvedUsers,omitempty" metadata:",optional"`

	// Automated Decision Making Consequences
	AutomatedDecisionMaking []string `json:"automated,omitempty" metadata:",optional"`
}

// {
//    "name":"prodName1",
//    "price":10,
//    "desc":"an updated",
//    "productType":"default/analytics/dataunion",
//    "policy":{
//       "inclPersonalInfo":true,
//       "hasconsent":true,
//       "purposes":[
//          "Marketing",
//          "Business"
//       ],
//       "protectionType":"SMPC",
//       "secondUseConsent":true,
//       "recipientType":EMPTY_STR,
//       "transferToCountry":false,
//       "storagePeriod":20
//    },
//    "escrow": "none"
// }

// UserInventory Object keeping track of a user's products (inventory)
type UserInventory struct {
	ObjectType string `json:"type"`

	// ProductIDs	[]string  		`json:"products"`
	Count int `json:"total"`
	Salt  int `json:"prodSalt"`
}


/* Agreement object */
type Agreement struct {
	ObjectType string `json:"type"`

	// Product
	TransactionID string  `json:"txID"`
	ProductID     string  `json:"productID"`
	ProductType   string  `json:"productType"`
	Seller        string  `json:"seller"`
	Buyer         string  `json:"buyer"`
	Price         float64 `json:"price"`
	Status        string  `json:"status"`
	Timestamp     int64   `json:"timestamp"`
}

type ProductHistoryQueryResult struct {
	Record    *Agreement `json:"record"`
	TxId      string     `json:"txId"`
	Timestamp time.Time  `json:"timestamp"`
	IsDelete  bool       `json:"isDelete"`
}
