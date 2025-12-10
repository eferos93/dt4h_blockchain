# Decentralized Network Deployment Guide

This document details the architecture, scripting infrastructure, and operational procedures for deploying the Hyperledger Fabric network in a **Hybrid/Decentralized** mode. In this configuration, specific organizations (e.g., `bsc`) are hosted on remote Virtual Machines (VMs) while the network orchestration remains centralized on a "Controller" machine.

---

## 1. Architecture Overview

The network transitions from a single-host deployment to a multi-host deployment using a **Controller-Worker** pattern over SSH.

### Topology

| Machine | Role | Components Hosted |
| :--- | :--- | :--- |
| **Local VM (Controller)** | Orchestrator & Host | • **athena (orderer org)**: orderers, CA, TLSCA<br>• **Athenapeers Org**: Peers, CA, TLSCA CouchDB<br>• **Ub Org**: Peers, CA, TLSCA, CouchDB<br>|
| **Remote VM (`bscbc`)** | Worker Node | • **BSC Org**: Peers (`peer0`, `peer1`), CA, TLSCA, CouchDB<br> |

### Communication Flow

1.  **Control Plane**: The Local VM executes scripts (`network.sh`) which send commands to the Remote VM via `ssh`.
2.  **Data Plane**:
    *   **Gossip**: Peers on Local and Remote VMs communicate via TCP (Ports 7051, 8051, etc.).
    *   **Synchronization**: `rsync` is used to transfer artifacts (Crypto material, Genesis blocks, Chaincode packages) between machines.

---

## 2. Standard Network Lifecycle

The `network.sh` script breaks down the network creation into 7 distinct steps. These can be executed sequentially or all at once using `./network.sh up`.

| Step | Command | Description |
| :--- | :--- | :--- |
| **Step 1** | `./network.sh step1` | **Create CAs**: Sets up Certificate Authorities for all organizations. Generates the root certificates. |
| **Step 2** | `./network.sh step2` | **Create Orderers and Peers**: Registers and enrolls identities (Orderers, Peers, Admins) with the CAs. Generates MSP structures. |
| **Step 3** | `./network.sh step3` | **Create Genesis Block**: Uses `configtxgen` to create the system genesis block based on the registered MSPs and `configtx.yaml`. |
| **Step 4** | `./network.sh step4` | **Start Nodes**: Spins up the Docker containers for Peers, Orderers, and CouchDB instances. |
| **Step 5** | `./network.sh step5` | **Create and Join Channel**: Creates the application channel and joins all peer nodes to it. |
| **Step 6** | `./network.sh step6` | **Deploy Chaincode**: Packages, installs, approves, and commits the chaincode definition to the channel. |

### Detailed Step Breakdown

#### Step 1: Create CAs (`createOrgs`)
*   **Script**: `network.sh` -> `clientCA.sh`
*   **Action**:
    *   Checks if organizations already exist.
    *   Iterates through `ORDERER_ORGS` and `PEER_ORGS`.
    *   Calls `./clientCA.sh setup_orgca` to start the Fabric CA server container.
    *   Calls `./clientCA.sh setup_orgmsp` to enroll the CA admin and generate the MSP structure.
*   **Production Mode**:
    *   For the `REMOTE_ORG`, it connects via SSH to the remote machine.
    *   Executes the CA setup remotely.
    *   **Sync**: Pulls the generated MSP from Remote to Local so the Genesis Block can be created in Step 3.

#### Step 2: Create Orderers and Peers (`createNodes`)
*   **Script**: `network.sh` -> `clientCA.sh`
*   **Action**:
    *   Registers and enrolls the **Orderer** identities.
    *   Registers and enrolls the **Peer** identities (`peer0`, `peer1`).
    *   Registers and enrolls **Admin** and **Client** users for the organization.
*   **Production Mode**:
    *   For the `REMOTE_ORG`, it executes `clientCA.sh register` and `enroll` commands on the remote machine via SSH.

#### Step 3: Create Genesis Block (`createConsortium`)
*   **Script**: `network.sh` -> `configtxgen`
*   **Action**:
    *   Uses the `configtx.yaml` configuration file.
    *   Generates the system genesis block (`system-genesis-block/dt4h.block`) using the MSPs generated in Step 1.
    *   This block is essential for bootstrapping the Orderer nodes.

#### Step 4: Start Nodes (`startNodes`)
*   **Script**: `network.sh` -> `peer.sh`
*   **Action**:
    *   Iterates through all nodes.
    *   Calls `./peer.sh start` which triggers `docker-compose up` to start the containers (Orderers, Peers, CouchDB).
*   **Production Mode**:
    *   For the `REMOTE_ORG`, it connects via SSH and starts the remote containers using the remote Docker daemon.

#### Step 5: Create and Join Channel (`createChannel`)
*   **Script**: `network.sh` -> `scripts/createChannel.sh`
*   **Action**:
    *   **Create Channel TX**: Generates the channel creation transaction using `configtxgen`.
    *   **Join Orderers**: Joins the Orderer nodes to the channel using `osnjoin`.
    *   **Join Peers**: Iterates through all peers and executes `peer channel join`.
*   **Production Mode**:
    *   **Sync**: Sends the `system-genesis-block` to the Remote machine.
    *   Executes `peer channel join` on the remote peers via SSH.
    *   **Sync**: Pulls the genesis block back to Local (to ensure consistency if the remote peer updated it).

#### Step 6: Deploy Chaincode (`deployCC`)
*   **Script**: `network.sh` -> `scripts/deployCC.sh`
*   **Action**:
    *   **Package**: Packages the chaincode (smart contract) into a `.tar.gz` file.
    *   **Install**: Installs the package on all peers (`peer0`, `peer1`) of all organizations.
    *   **Approve**: Each organization approves the chaincode definition.
    *   **Commit**: The definition is committed to the channel once enough approvals are gathered.
*   **Production Mode**:
    *   **Sync**: Sends the chaincode package (`.tar.gz`) to the Remote machine.
    *   Executes `install` and `approve` on the remote peers via SSH.
    *   **Ideal Solution**: move the chaincode in separate repo and use a CI/CD pipeline with Github Actions

---

## 3. Scripting Infrastructure

The bash scripts have been refactored to support a `STAGE` environment variable. When `STAGE="prod"`, the scripts execute conditional logic to handle remote organizations.

### Key Configuration Files

*   **`configGlobals.sh`**:
    *   **`STAGE`**: Defaults to `dev`. If set to `prod`, enables remote logic.
    *   **`REMOTE_ORG`**: The name of the organization to deploy remotely (e.g., `bsc`).
    *   **`REMOTE_HOST`**: The SSH alias or IP of the remote machine.
    *   **`REMOTE_FABRIC_HOME`**: The absolute path to the `fabric` folder on the remote machine.

### Core Logic (`network.sh`)

The `network.sh` script acts as the master controller. It iterates through organizations and checks if the current org matches `$REMOTE_ORG` and if `$STAGE` is `prod`.

*   **Local Execution**: Standard function calls (e.g., `./clientCA.sh setup_orgca`).
*   **Remote Execution**: Wrapped in SSH calls.
    ```bash
    ssh ${REMOTE_SSH} "cd ${REMOTE_FABRIC_HOME} && ./clientCA.sh setup_orgca -o $org"
    ```

### Data Synchronization Strategy

To maintain consistency across the distributed network, specific artifacts must be synchronized at specific times:

| Step | Artifact | Direction | Reason |
| :--- | :--- | :--- | :--- |
| **1. Create Orgs** | `organizations/peerOrganizations/bsc...` | **Remote -> Local** | The Local machine needs the Remote Org's MSP (Certificates) to generate the **Genesis Block**. |
| **2. Create Channel** | `system-genesis-block` | **Local -> Remote** | The Remote peers need the genesis block to join the channel. |
| **3. Create Channel** | `system-genesis-block` (Updated) | **Remote -> Local** | If the remote peer updates the config (e.g., anchor peers), the block might need to be synced back (though usually handled by Gossip/Orderer). |
| **4. Deploy CC** | `chaincode.tar.gz` | **Local -> Remote** | The chaincode package must be physically present on the remote machine to be installed. |

---

## 4. Prerequisites & Setup

### A. Remote Machine Setup (`bscbc`)

1.  **OS**: Ubuntu Linux (Recommended).
2.  **User**: Create a user (e.g., `ubuntu`) that matches the `REMOTE_USER` config.
3.  **Software**:
    *   **Docker & Docker Compose**: Installed and running. User must be in the `docker` group (`sudo usermod -aG docker $USER`).
    *   **Fabric Binaries**: Download Fabric binaries and place them in `~/fabric/bin` or ensure they are in the system `$PATH`.
4.  **Repository**:
    *   Clone the repository to the home folder:
        ```bash
        git clone <your-repo-url> ~/fabric
        ```

### B. Local Machine Setup (Controller)

1.  **SSH Configuration**:
    *   Edit `~/.ssh/config` to define the remote host alias. This avoids hardcoding IPs in scripts.
        ```ssh
        Host bscbc
            HostName <REMOTE_IP_ADDRESS>
            User ubuntu
            IdentityFile ~/.ssh/id_rsa
        ```
2.  **SSH Keys**:
    *   Generate a keypair if needed: `ssh-keygen -t rsa`
    *   Copy public key to remote: `ssh-copy-id bscbc`
    *   **Verification**: Run `ssh bscbc ls` and ensure it returns the file list without asking for a password.

---

## 5. Deployment Guide

### Step 1: Start the Network (Production Mode)

Run the network script with the `--prod` flag. This sets `STAGE="prod"` globally.

```bash
# Ensure you are in the fabric directory
cd ~/fabric

# Run the script (Do NOT use sudo if your user has docker rights, otherwise ensure root has SSH access)
./network.sh up --prod
```

**Detailed Execution Flow:**
1.  **`createOrgs`**: Connects to `bscbc`, generates CA and MSPs for `bsc`. Syncs MSPs back to Local.
2.  **`createNodes`**: Connects to `bscbc`, registers/enrolls peers.
3.  **`createConsortium`**: Uses Local and Synced Remote MSPs to create `genesis.block`.
4.  **`startNodes`**: Starts Local containers. Connects to `bscbc` and runs `docker-compose up` for `bsc` peers.
5.  **`createChannel`**:
    *   Creates channel TX locally.
    *   `rsync` genesis block to `bscbc`.
    *   SSH to `bscbc` -> `peer channel join`.
6.  **`deployCC`**:
    *   Packages chaincode locally.
    *   `rsync` package to `bscbc`.
    *   SSH to `bscbc` -> `peer lifecycle chaincode install`.
    *   SSH to `bscbc` -> `peer lifecycle chaincode approveformyorg`.

### Step 2: Verify Deployment

1.  **Check Local Nodes**:
    ```bash
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    ```
2.  **Check Remote Nodes**:
    ```bash
    ssh bscbc "docker ps --format 'table {{.Names}}\t{{.Status}}'"
    ```
    *   You should see `peer0.bsc.dt4h.com`, `couchdb`, etc.

### Step 3: Stop the Network

To tear down the network across **both** machines:

```bash
./network.sh down --prod
```

*   This command first connects to the remote machine and executes `./network.sh down` locally there to clean up containers and artifacts.
*   Then it cleans up the local environment.

---

## 6. Troubleshooting

### Common Issues

1.  **`Permission denied (publickey)`**:
    *   **Cause**: The user running the script (e.g., `root` via `sudo`) does not have the SSH keys or config setup for `bscbc`.
    *   **Fix**: Run as a non-root user who has SSH access and Docker rights. Or, copy `~/.ssh` to `/root/.ssh`.

2.  **`rsync: connection unexpectedly closed`**:
    *   **Cause**: SSH connection failed or remote path does not exist.
    *   **Fix**: Verify `REMOTE_FABRIC_HOME` in `configGlobals.sh` matches the actual path on the remote VM.

3.  **`channel creation failed` / `genesis block not found`**:
    *   **Cause**: The MSP sync step failed, so the genesis block was created without the remote org's certificates.
    *   **Fix**: Check the logs of `createOrgs` to ensure `rsync` from Remote to Local succeeded.

4.  **Chaincode Installation Failed**:
    *   **Cause**: The chaincode package was not synced correctly or the remote peer container is not running.
    *   **Fix**: Check `deployCC.sh` logs and verify remote docker containers are up.

---

## 7. Future Improvements

*   **Ansible Migration**: Replace the Bash+SSH logic with Ansible Playbooks for more robust, idempotent, and readable configuration management.
*   **VPN / Overlay Network**: Currently, peers communicate via public/private IPs. Using a Docker Swarm overlay network or a VPN (WireGuard) would simplify port management and security.
