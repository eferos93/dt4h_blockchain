# HLF Backend Application for Krakenh2020 - Application

## Description

A backend code is provided in Typescript with various functionalities such as: 
* Interaction with the CA Servers
* Replication of the Blockchain in a MongoDB
* Offline Signing Transactions (in the Browser)
* Invoking Smart Contracts
* Other utility functionalities

## Installation

```bash
npm gen_mod
npm run init
```

## Application-Libraries

### libCAServices.js 
Fabric CA Client functionality

### libUserContract 
User CRUD functionality and queries

### libDataContract
Product CRUD functionality and queries

###  libAgreementContract
Agreement CRU functionality and queries

### libBlockListener
Implements the Smart Contract event listener to catch block data 

###  libReplicateDB
Implementation on replicating the ledger on a MongoDB via the BlockListener

### libQuery
Functions implementing query operations on the MongoDB

### libUtil
Helper functions

### libCrypto
Contains cryptographic related functions, e.g PEM encodings, x509 certs, creating CSRs

### libGrpc
Contains client to communciate with an organization's peer, mainly
to trigger Certificate Revocation List Channel Update.

## Usage

On a new shell, to listen for Blocks and update the Database:
```bash
npm run db_listen
```

On a new shell, to observe the DB-Ledger sync run:
```bash
npm run db_validate
```

On a new shell, to perform CA and chaincode operations:
```bash
npm run test
```

See app.js for all operations included


## Application-Logging

Use console for console stdout or filepath for file
```bash
export APP_LOGGING='{"debug":"console"}'
export APP_LOGGING='{"debug":"debug.log"}'
export APP_LOGGING='{"debug":"debug.log", "info":"console"}'
```
OR configure it from .env file 

## Docs
```bash
open kraken-app/docs/index.html
```

## Folder Structure

kraken-app/lib 		<!-- Typescript code and implementation of the package -->
kraken-app/dist		<!-- Destination of js (transpiled .ts) files -->
kraken-app/test		<!-- Unit tests -->
build_proto_ts.sh   <!-- Script to generate .js and .ts from .proto files (used for grpc) -->
index.js 			<!-- Export all relevant data structures -->

## Compile 

```bash
tsc 
```
Or for continuous compilation:

```bash
tsc -w
```

## For Deployment

At .env set AS_LOCALHOST=false
