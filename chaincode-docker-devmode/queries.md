
###### INIT 

peer chaincode install -p chaincode -n mycc -v 0
peer chaincode instantiate -n mycc -v 0 -c '{"Args":[]}' -C myc


###### .
###### USER 
###### .

```js
{
  "username": "seller",
  "isOrg": false,
  "isBuyer": false,
  "purposes": [
    "Marketing"
  ],
  "active": true
}

{
  "username": "companyA",
  "isOrg": true,
  "isMemberOf": "companyA",
  "org": {
    "instType": "privateHospitals",
    "orgName": "Lynkeus",
    "active": true,
    "members": []
  },
  "isBuyer": true,
  "purposes": [
    "Marketing"
  ],
  "active": true
}
```

```js
{
  "name": "testProduct1",
  "price": 10,
  "desc": "An analytics product",
  "sector": "Health and wellness",
  "productType": "ANALYTICS",
  "policy": {
    "inclPersonalInfo": true,
    "hasConsent": true,
    "purposes": [
      "Marketing"
    ],
    "protectionType": "SMPC",
    "secondUseConsent": true,
    "recipientType": ["hr_agencies"],
    "transferToCountry": "eu",
    "storagePeriod": 20,
    "approvedOrgs": [""],
    "approvedUsers": ["companyA"],
    "automated": ["automated_placing"]
  },
  "curations": []
}


```

## User Queries

** 
peer chaincode query -n mycc -C myc -c '{"Args":["UserContract:GetAllUsers"]}' | jq

**
peer chaincode query -n mycc -C myc -c '{"Args":["UserContract:ReadUser", "Alex"]}' | jq

## User Invocations

**
peer chaincode invoke  -n mycc -C myc -c '{"Args":["UserContract:CreateUser", "{\n  \"username\": \"companyA\",\n  \"isOrg\": true,\n  \"isMemberOf\": \"companyA\",\n  \"org\": {\n    \"instType\": \"PrivateHospitals\",\n    \"orgName\": \"Lynkeus\",\n    \"active\": true,\n    \"members\": []\n  },\n  \"isBuyer\": true,\n  \"purposes\": [\n    \"Marketing\"\n  ],\n  \"active\": true\n}"           ]}' 

**
peer chaincode invoke  -n mycc -C myc -c '{"Args":["UserContract:UpdateUser", "{\n  \"username\": \"companyA\",\n  \"isOrg\": true,\n  \"isMemberOf\": \"\",\n  \"org\": {\n    \"instType\": \"publicHospitals\",\n    \"orgName\": \"Lynkeus\",\n    \"active\": true\n  },\n  \"isBuyer\": true,\n  \"purposes\": [\n    \"Marketing\"\n  ],\n  \"active\": true\n}"]}' 

**
peer chaincode invoke  -n mycc  -c '{"Args":["UserContract:DeleteUser","Alex"]}' -C myc


###### .
###### DATA
###### .

## Product History


peer chaincode query -n mycc -C myc -c '{"Args":["DataContract:GetProductHistory", "2355a1588b4a988ab3cac9ebcee1048e74ef44caa83f55f4badbf2553d032956"]}' | jq 


## Buy Product

peer chaincode invoke -n mycc -C myc -c '{"Args":["DataContract:BuyProduct", "0c672fa72156d86a7410a250ad029ec95d15d7add80605771eb6837574a7443d" ,   "{\n   \"purposes\":[\"Marketing\"]\n}"      ]}' | jq 


## Data Queries 
peer chaincode query -n mycc -C myc -c '{"Args":["DataContract:ReadProduct", "prod4"]}' | jq 

peer chaincode query -n mycc -C myc -c '{"Args":["DataContract:GetAllProducts"]}' | jq 


## Data invocations

## CREATE
peer chaincode invoke -C myc -n mycc  -c '{"Args":["DataContract:CreateProduct",   "{\n  \"name\": \"testProduct1\",\n  \"price\": 10,\n  \"desc\": \"An analytics product\",\n  \"sector\": \"Health\",\n  \"productType\": \"Analytics\",\n  \"policy\": {\n    \"inclPersonalInfo\": true,\n    \"hasConsent\": true,\n    \"purposes\": [\n      \"Marketing\"\n    ],\n    \"protectionType\": \"SMPC\",\n    \"secondUseConsent\": true,\n    \"recipientType\": [\"PrivateHospitals\"],\n    \"transferToCountry\": \"eu\",\n    \"storagePeriod\": 20,\n    \"approvedOrgs\": [\"\"],\n    \"automated\": [\"automated_placing\"]\n  },\n  \"curations\": []\n}\n"  ]}'  

## UPDATE
peer chaincode invoke  -C myc -n mycc  -c '{"Args":["DataContract:UpdateProduct", "{\n  \"name\": \"testProduct1\",\n  \"price\": 10,\n  \"desc\": \"An analytics product\",\n\t\"id\": \"2355a1588b4a988ab3cac9ebcee1048e74ef44caa83f55f4badbf2553d032956\",\n  \"sector\": \"Health\",\n  \"productType\": \"Analytics\",\n  \"policy\": {\n    \"inclPersonalInfo\": true,\n    \"hasConsent\": true,\n    \"purposes\": [\n      \"Marketing\"\n    ],\n    \"protectionType\": \"SMPC\",\n    \"secondUseConsent\": true,\n    \"recipientType\": [\"PrivateHospitals\"],\n    \"transferToCountry\": \"eu\",\n    \"storagePeriod\": 20,\n    \"approvedOrgs\": [\"\"],\n    \"Automated\": [\"AutomatedPlacing\"]\n  },\n  \"curations\": []\n}\n"]}'  

## DELETE
peer chaincode invoke  -n mycc  -c '{"Args":["DataContract:DeleteProduct", "90d74d822fcb410a41dc000c3df9b46821d85211b8ff5e7158ab867f6c938ca0"]}' -C myc


###### .
###### AGREEMENT
###### .

## UPDATE

peer chaincode invoke -n mycc -C myc -c '{"Args":["AgreementContract:UpdateAgreement", "TXID" , "Access" ]}' | jq 

<!-- peer
peer chaincode query -n mycc -C myc -c '{"Args":["AgreementContract:IsEligible", "0c672fa72156d86a7410a250ad029ec95d15d7add80605771eb6837574a7443d"]}' | jq -->

## QUERY

peer chaincode query -n mycc -C myc -c '{"Args":["AgreementContract:GetTransactions"]}' | jq 


peer chaincode query -n mycc -C myc -c '{"Args":["ManagementContract:UpdateCRL", "-----BEGIN X509 CRL-----\nMIIBaDCCAQ4CAQEwCgYIKoZIzj0EAwIwajEOMAwGA1UEBhMFSVRBTFkxEDAOBgNV\nBAgTB0xZTktFVVMxFDASBgNVBAoTC0h5cGVybGVkZ2VyMQ8wDQYDVQQLEwZGYWJy\naWMxHzAdBgNVBAMTFmZhYnJpYy1jYS1zZXJ2ZXItdXNlcnMXDTIyMDgwMTEwNDkw\nNFoXDTIyMDgwMjEwNDkwNFowTjAlAhQibwS+eQHa2arJgClC7uFaAuy9rRcNMjIw\nNzI4MDg1MDA2WjAlAhRUN31jbiP3NinJ27sN4GXBAl45dBcNMjIwODAxMTA0MDQ5\nWqAjMCEwHwYDVR0jBBgwFoAUpig1PK0/sutlrut+Xy5Qp4D2HTAwCgYIKoZIzj0E\nAwIDSAAwRQIhAMKjEkTM00G1jAriAptN3vXxAcgjajkoJT1AvXB+uZOaAiAW6y/e\nLMSjANTcp0OsqeN/KZW6gOvvA5OzUnwNDhukUw==\n-----END X509 CRL-----\n"]}'

