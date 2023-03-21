## Hyperledger Fabric Network for Krakenh2020

A Hyperledger Fabric network and application impelementation automatically generated based on user preferences. The chaincode leverages a marketplace solution for personal data using data access policies and permissions set by the data sellers.

### Description

#### Network
This project provides tools automating the creation of an HLF network while providing minimal configuration. We provide several APIs which ease the development and production deployment. The APIs are:
* caAPI: Provides CA related functionalities such as register, enrolling, viewing identities, creating CAs etc.
* peerAPI: Peer related functionalities including chaincode lifecycle commands, performing channel updates, joining channel etc.
* toolsAPI: Various helper functions for the management of the folder structuring mainly in the deployment.

#### Application
Additionally, a backend code is provided in Typescript with various functionalities such as: 
* Interaction with the CA Servers
* Replication of the Blockchain in a MongoDB
* Offline Signing Transactions (in the Browser)
* Invoking Smart Contracts
* Other utility functionalities


### Installation

If on local machine:
```bash
./tools.sh setup
```

If on a remote VM:
See beginning of DEPLOY.md for prerequisites installation

### Starting the network

On fabric directory:
```bash
make init
```

### Execution flow

* The network.sh script executes commands for each organization listed to create a network, channel and deploy a chaincode. The configuration files of each node and CAs are listed in the config folder, while some parameters for each organization are hard coded in util.sh
* The creation of docker-compose files is automated.

### Folder Structure

- application-typescript: The backend Typescript libraries to interact with Fabric network
- blockchain-explorer: A tool to monitor the Blockchain (Blocks, Nodes, etc...)
- api/caAPI: A customized API for the Fabric CA
- chaincode: The chaincode packages (mhmdCC, smpcCC atm)
- config: Configuration files for all CAs, Peers, Orderers and other
- config-dev: Configuration for Dev Environment
- config-prod: Configuration for Production Environment
<!-- - grpc-comms: Client to commnunicate with the Backend Application build with GRPC (focus is CRL updates) -->
- organizations: All MSPs
- api/peerAPI: A customized API for a Peer Node
- scripts: Various scripts for network operations
<!-- - smpc-application: Application used by SMPC Coordinator to invoke chaincode on Fabric network -->
- tests: Network tests
- api/toolsAPI: A Customised API for various deployment operations
ccp.yaml: Contains hostnames and IPs of Nodes and CAs
clientCA.sh, peer.sh, tools.sh: Clients for the APIs
configCC.sh: Configuration of the chaincode (when commit)
grafana_dashboard: Used by grafana to monitor nodes
network.sh: Perform network operations (start, createChannel, deployCC, delete, ...)
util.sh: Contains utility functions and env vars
Makefile: User friendly api for basic setup functionalities
configGlobals.sh: Configuration of global network variables 

### Status
In development

### License
TBD