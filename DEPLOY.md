##### ------------ #####
##### Setup the VM #####
##### ------------ #####

FABRIC VERSION = 2.2.5
CA VERSION = 1.5.1

## Prepare your workspace (Copy - paste commands)
```bash

make remote_init_vm

mkdir -p ~/workspace
sudo apt-get update
sudo apt-get install make

make init_vm
OR
sudo apt-get install  apt-transport-https ca-certificates curl lsb-release -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update 
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose -y
sudo apt-get install yq jq tree -y
sudo usermod -aG docker $USER
echo "Relogin to VM for docker permissions to take effect." 

```



``` bash
```

# Re- login to VM for usermod to take effect

## Copy fabric folder from host to node
```bash
scp -r  /path/to/fabric/folder username@ip:$HOME/workspace
OR
rsync -v -a /path/to/fabric/folder -e 'ssh -p $port' --exclude 'bin' username@host:~/workspace/
rsync -v -a deploy -e "ssh -i $key" --exclude 'bin' user@host:~/workspace/

OR
./tools.sh transferAll .
```

## Get full permissions on folder
```bash
chmod -R 755 $folder
```

## Download fabric binaries - images and GO (if not installed)
```bash
cd ~/workspace/fabric
make setup
source ~/.bashrc
```

## Add fabric/bin to $PATH 

## Config CAs
On the config directory, there are the configurations for all CAs, peers and orderers.
CAs start with fca- followed by [ca or tls] for CA or TLS CA respectively.
On their configuration files specify the hosts in the following section:

```yaml
csr:
   hosts:
     - localhost
     - lynkeus.domain.com
     - your.host
```

# On file configGlobals.sh change the values on setParams specified by the comment block


## Config HOSTS
Configure IPs and hostnames of all nodes. See setup-tools/configHosts.sh

```bash
sudo ./tools.sh configHosts
```

## Change to production env
```bash
sudo ./tools.sh switchNet prod
```




##### ------------------ #####
##### Create the Network #####
##### ------------------ #####





## Bring up CAs and create Organization Admin MSP (Channel MSP)
```bash
./network.sh step1
```

The Channel MSP of each organization will be used to configure the genesis block.

## Transfer Channel MSP to the ordering service to bootstrap the genesis block

From the fabric directory:
```bash
sudo ./tools.sh exportOrg [orgName] [peer or orderer]
scp [orgname].domain.com.tar.gz OrdererHostname@IP:~/workspace/fabric
or rsync
```

## Create Nodes Orderer and Peers

On script network.sh, set peerOrgs and ordererOrgs.
For example, if you want to create a peer organization, then set your organization name 
on peerOrgs and comment out ordererOrgs
Then,

```bash
sudo ./network.sh step2
```

## (Orderer only) Create the genesis block

First import the Channel MSPs of other organizations and then create the genesis block


```bash
sudo ./tools.sh importOrg [path/of/tar.gz] peer
sudo ./network.sh step3
```

## Transfer the genesis block to all orderers

```bash
scp or 
rsync -av system-genesis-block -e 'ssh -p 15000' orderer0@ordererIP:path/to/fabric
```


## Start the nodes

# Orderers first!
Copy the crypto material of every node to the corresponding VM.
To do this, you need to extract the node MSP and transfer it:
See the manual for exportNode

```bash
./tools.sh exportNode [ORG_NAME] [ORG TYPE] [NODE NAME]
./tools.sh exportNode org1 orderer orderer0.org1.domain.com
scp or rsync to orderer2IP
```

Then on VM
```bash
./tools.sh importNode path/to/file
cd -
./peer.sh start -t [NODE_TYPE] -n [NODE_NAME] -p [PORT]  
```

# Export Ordererorg and import it on the peer Organizations
# Also, export peer orgs and import them to the org creating the channel
# because the certs are needed for the channel configuration transaction






##### ------------------ #####
##### Create the Channel #####
##### ------------------ #####

##### PEER (Channel and Chaincode Operations)

## Using the network.sh script

For channel/chaincode operations the peer ./network.sh script can be used as a fast first setup.
The defaults are stored in configCC.sh and should be adjusted from there.

```bash
sudo ./network.sh step5
```

NOTE! The script will fail if the peers are not yet started but the channel will be created.
After the peers are deployed, the admin will need to join them to the channel


Step5: Create Channel Transaction -> Submit Channel Creation -> Join peers to channel

## Using the peer.sh API

The peer API provides functionality for setting up channel and chaincodes.
The defaults can be overriden using input arguments.
However, adjusting the arguments from configCC.sh is recommended so they persist.

```bash
./peer.sh -h
```

## Create Channel (1 org only)

```bash
./network.sh step5
```

# Broadcast channel block to other peer organizations (rsync/scp)
# Block should be stored as $FABRIC_HOME/channel-artifacts/${CHANNEL_NAME}.block

```bash
./peer.sh joinchannel -p peer0.org.domain.com -A
```

# Verify

```bash
./peer.sh listchannel -p peer0.org.domain.com
```

# If anchor peers are not updated on the step5 phase, then run 

```bash
./peer.sh updateanchorpeers -o [ORG_NAME] -O [ORG_MSPID]
```


##### ---------------- #####
##### Deploy Chaincode #####
##### ---------------- #####

Configuring values from configCC.sh is encouraged.

## Deploy Chaincode


```bash
./network.sh step6
```

OR 

```bash
./peer.sh package
```

# Broadcast the package to other peer organizations
# Install chaincode to peers (2 org)

```bash
./peer.sh install -n peer0.org.domain.com
./peer.sh install -n peer1.org.domain.com
```

# Verify installation

```bash
./peer.sh queryinstalled -n peer0.org.domain.com
```

# Approve chaincode as org (2 org)

```bash
./peer.sh approve -n peer0.org.domain.com
```

# Verify

```bash
./peer.sh queryapproved -n peer0.org.domain.com
```

# Check if chaincode is approved by sufficient orgs (1 org)

```bash
./peer.sh checkreadiness -n peer0.org.domain.com
```

# Commit chaincode to channel (1 org)

```bash
./peer.sh commit -n peer0.org.domain.com
```

# Verify commit (2 orgs)

```bash
./peer.sh querycommitted -n peer0.org.domain.com
```


##### ---------------- #####
##### Setup Monitoring #####
##### ---------------- #####

To setup Prometheus, the server must obtain the TLS certs from org/users/prometheus. Export the Prometheus MSP and import it on the server running Prometheus. Then:

```bash
./network.sh metrics
```


##### ---------------- #####
##### Update Chaincode #####
##### ---------------- #####


To add struct parameters, the newly listed parameter must have 
```
metadata:",optional 
```
Example:
```go
ProductIDs  []string  `json:"productIDs, omitempty" metadata:",optional"`
```

Explained: 
This is as intended, the json is compared against the metadata schema. By default all fields are required, using omitempty will mean that the JSON process will remove that field when it has no value. This means a required field will be missing. To fix this add a metadata tag to mark the field as optional metadata:",optional"
