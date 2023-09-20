
## Agora Labs Hyperledger Fabric

  

A Hyperledger Fabric wrapper framework to deploy a custom network and an application implementation automatically generated based on user preferences, leveraging a marketplace solution for personal data using data access policies and permissions set by the data sellers.

  
  

### Description
The framework is split in 3 parts: HF network, application code, and chaincode.
  

#### Network

This project provides tools automating the creation of an HLF network while providing minimal configuration. Several APIs are provided which ease the development and production deployment. The APIs are:

* caAPI (clientCA.sh): Provides CA related functionalities such as register, enrolling, viewing identities, creating CAs etc.

* peerAPI (peer.sh): Peer related functionalities including chaincode lifecycle commands, performing channel updates, joining channel etc.

* toolsAPI (tools.sh): Various helper functions for the management of the folder structuring mainly in the deployment.


In development mode, setting up a complete network is easy. You can use the **network.sh** script as the entry point to perform the operations required to set up a network in distinct steps, based on the configurations given in configGlobals.sh (general config) and configCC.sh (for channel and chaincode). The steps are listed below:

1. Setup the Certificate Authorities (CA). At this step, each organization creates a CA, a TLS CA, and a TLS Ops CA (for operations). The required admins, peers, and orderers are registered and enrolled to these servers and the MSPs are generated and saved at organizations/org_name.domain.com
2. Setup Node MSPs. As the CAs are created and the nodes are registered, the next step is to create the node MSPs to start them operating. Every node is enrolled on their respective CAs and an MSP is created under organizations/org_name.domain.com/peers/peer_id.org_name.domain.com
3. Create the genesis block configuration. Created using the configuration at configtx.yaml and a selected profile, it is required and used when setting up a new channel.
4. Start the nodes. Bring up all docker containers of the nodes so they start operating and communicating.
5. Create a channel. At this point, a new channel is created using the genesis configuration. Each peer of the organizations is joined to the channel (using an Admin's MSP).
6. Install a chaincode. After the channel is created, the chaincode is installed on all the peers and then approved and committed to the channel.



  

#### Application

Additionally, a Typescript application code is provided with functionalities such as:

* Register/enrolling to a CA Server

* Replication of the Blockchain in a MongoDB

* Offline Signing Transactions

* Chaincode interaction

* Other utility functionalities

  
  

### Installation

  

If on local machine:

```bash

./tools.sh  setup

```

  

If on a remote VM:

See beginning of DEPLOY.md for prerequisites installation

  

### Starting the network

  

On fabric directory:

```bash

make  init

```

  

### Execution flow

  

* The network.sh script executes commands for each organization listed to create a network, channel and deploy a chaincode. The configuration files of each node and CAs are listed in the config folder, while some parameters for each organization are hard coded in configGlobals.sh

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