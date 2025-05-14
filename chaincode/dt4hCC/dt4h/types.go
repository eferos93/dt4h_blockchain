package dt4h

import (
	"time"

	"github.com/hyperledger/fabric-contract-api-go/contractapi"

	// "log"
	"fmt"
	// "math/big"
	// "github.com/zmap/zcrypto/encoding/asn1"
	// x509 "github.com/zmap/zcrypto/x509"
	// "github.com/zmap/zcrypto/x509/pkix"
)

// Versioning
const CURRENT_PRODUCT_VERSION = 0
const CURRENT_USER_VERSION = 0
const VERSION_FIELD = "vers"

const TRUE = "true"
const FALSE = "false"
const EMPTY_STR = ""

const (
	ADMIN   string = "admin"
	PEER    string = "peer"
	CLIENT  string = "client"
	ORDERER string = "orderer"
)

const (
	USER_OBJECT_TYPE         = "user"
	USERID_OBJECT_TYPE       = "userID"
	PRODUCT_OBJECT_TYPE      = "product"
	AGREEMENT_OBJECT_TYPE    = "agreement"
	INVENTORY_OBJECT_TYPE    = "inventory"
	REVOKED_CERT_OBJECT_TYPE = "revoked"
	ORG_OBJECT_TYPE          = "org"
)

const (
	HEALTH    = "Health"
	EDUCATION = "Education"

	ANALYTICS = "Analytics"
	BATCH     = "Batch"
	STREAMS   = "Streams"
)

const (
	AUTOMATED_DECISION_MAKING = "Automated"
)

var AUTHORIZED_MSPS = []string{"UbMSP", "AthenaMSP", "BscMSP"}
var AGREEMENT_STATUS = []string{"Eligible", "Paid", "Access", "Withdrawn"}
var PURPOSES = []string{"Marketing", "PubliclyFundedResearch", "PrivateResearch", "Management", "Automated", "StudyRecommendations", "JobOffers", "StatisticalResearch"}
var PROTECTIONS = []string{"Anonymization", "Encryption", "SMPC"}
var PRODUCT_SECTOR = []string{HEALTH, EDUCATION}
var PRODUCT_TYPES = []string{BATCH, ANALYTICS, STREAMS}
var EDUCATIONAL_INSTITUTION_TYPES = []string{"HrAgencies", "PrivateCompanies", "PublicInstitutions", "PublicResearchCenters", "PublicResearchInstitutions"}
var HEALTH_INSTITUTION_TYPES = []string{"PublicHospitals", "PrivateHospitals", "PrivateResearch", "PublicResearch", "Governments", "PrivateCompanies", "Other"}
var AUTOMATED_DECISION_MAKING_CONSEQUENCES = []string{"AutomatedPlacing", "HiringAssessment", "ClinicalResearchAssessment", "DiagnosticOrTreatment"}
var INSTITUTIONS = append(HEALTH_INSTITUTION_TYPES, EDUCATIONAL_INSTITUTION_TYPES...)

// var DATA_ACCESS_LEVELS = []string{"level_1", "level_2", "level_3"}

type RevokedCertificate struct {
	ObjectType string `json:"type"`
	MspID      string `json:"mspid"`
	// Data 	   	pkix.RevokedCertificate
	SerialNumber   string    `json:"serialNumber"`
	RevocationTime time.Time `json:"revocationTime"`
	Key            string    `json:"key"`
}

type Query struct {
	Query     string `json:"query"`
	Timestamp string `json:"timestamp"`
}
type UserHistory struct {
	User    string  `json:"user"`
	Queries []Query `json:"queries"`
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

type QueryContract struct {
	contractapi.Contract
}

var agreementContract = new(AgreementContract)
var userContract = new(UserContract)
var managementContract = new(ManagementContract)
var dataContract = new(DataContract)
var queryContract = new(QueryContract)

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
	MspID    string `json:"mspid"`

	// Org Are you sharing/looking for data on behalf of an organization such as a private company or a research center?
	IsOrg bool `json:"isOrg"`

	// True if the user is a member of the organization and not the admin
	IsMemberOf string `json:"isMemberOf,omitempty" metadata:",optional"`
	Org        Org    `json:"org,omitempty" metadata:",optional"`

	IsBuyer bool `json:"isBuyer"`

	// As a buyer, preferences to filter the marketplace (not used?)
	Purposes []string `json:"purposes,omitempty" metadata:",optional"`

	// Validity period of user, upon expiration their products are not accessible
	ValidTo time.Time `json:"validTo"`

	// Key of certificate
	CertKey string `json:"certKey" metadata:",optional"`

	// Active status
	Active bool `json:"active"`

	Version int64 `json:"vers" metadata:",optional"`
}

type OrgData struct {
	Verified bool     `json:"verified"`
	Members  []string `json:"members,omitempty" metadata:",optional"`
}

type Org struct {
	// identity and contact details of the controller, and DPO if applicable
	InstType string `json:"instType"`
	OrgName  string `json:"orgName"`
	Active   bool   `json:"active"`

	// Users transacting on behalf of the organization
	Members []string `json:"members,omitempty" metadata:",optional"`

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

	if !_in(o.InstType, INSTITUTIONS) {
		return fmt.Errorf("%s - Undefined institution value: %s", method, o.InstType)
	}

	if o.OrgName == EMPTY_STR {
		return fmt.Errorf("%s - Missing Organization Name", method)
	}
	if len(o.Members) == 0 {
		o.Members = []string{}
	}
	//  else {
	// 	o.Members =
	// }

	return nil
}

// BuyerParams The buyer's input to validate against product's policy
type BuyerParams struct {
	Purposes []string `json:"purposes"`
	// Data Access Level
	DataAccessLevel string `json:"dataAccessLevel" metadata:",optional"`
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

	// SMPC metadata
	Epsilon float64 `json:"epsilon,omitempty" metadata:",optional"`

	DataAccessLevels []DataAccessLevel `json:"dataAccessLevels,omitempty" metadata:",optional"`

	// In case of a Data Union
	// ProductIDs []string `json:"productIDs,omitempty" metadata:",optional"`
	Version int64 `json:"vers" metadata:",optional"`
}

// Access tiers
type DataAccessLevel struct {
	Level string  `json:"level"`
	Price float64 `json:"price"`
	Units float64 `json:"units"`
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
	SecUseConsent bool     `json:"secondUseConsent,omitempty" metadata:",optional"`
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

	Version int64 `json:"vers" metadata:",optional"`
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

	// Data Access Level
	DataAccessLevel string `json:"dataAccessLevel"`

	Version int64 `json:"vers" metadata:",optional"`
}

type ProductHistoryQueryResult struct {
	Record    *Product  `json:"record"`
	TxId      string    `json:"txId"`
	Timestamp time.Time `json:"timestamp"`
	IsDelete  bool      `json:"isDelete"`
}

type ProductTxHistoryQueryResult struct {
	Record    *Agreement `json:"record"`
	TxId      string     `json:"txId"`
	Timestamp time.Time  `json:"timestamp"`
	IsDelete  bool       `json:"isDelete"`
}
