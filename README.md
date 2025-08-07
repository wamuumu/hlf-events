# Hyperledger Fabric Events

## Overview
A comprehensive blockchain network implementation demonstrating dynamic organization management, chaincode deployment and event monitoring using a dedicated NodeJS application. This project showcases a complete multi-organization blockchain network with real-time event listening capabilities and supports dynamic addition and removal of organizations during runtime.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Network structure](#network-folder-structure)
- [Getting Started](#getting-started)
- [Hyperledger Fabric Network](#hyperledger-fabric-network)
- [NodeJS application](#nodejs-application)

## Prerequisites

To run this project, ensure that all the following dependencies are installed and available in the Unix system. 

- **[Docker](https://www.docker.com/)** - Container platform for running the Fabric network infrastructure
- **[Node.js](https://nodejs.org/)** (version 18 or higher) - JavaScript runtime for the client application
- **[npm](https://www.npmjs.com/)** - Package manager for handling NodeJS dependencies

## Hyperledger Fabric Network

The `network` directory includes all assets necessary for configuring and operating the Hyperledger Fabric network. Its structure is outlined as follows:

```
network/
├── bin/
│   └── (Hyperledger Fabric binaries)
├── channel/
│   └── (generated artifacts from network operations)
├── compose/
│   └── (docker compose files for service definition)
├── config/
│   ├── core.yaml (common definition file for all peers)
│   ├── orderer.yaml (common definition file for all orderers)
├── configtx/
│   └── (channel definition files for blockchain network)
├── crypto/
│   └── (definition files to for crypto material generation)
├── identities/
│   └── (generated certificates and MSP folders of participant) (public)
├── organizations/
│   └── (generated certificates and MSP folders of participant) (private)
├── package/
│   └── (chaincode packages to install on the channel)
├── scripts/
│   └── (bash commands to setup and run the whole infrastructure)
├── network.config (definition file for env variables)
└── README.md (this file)
```

### Getting started
To get started with this project, first clone the repository to your local machine:

```bash
git clone https://github.com/your-username/hlf-events.git
cd hlf-events/network
```

Make sure you have all prerequisites installed before proceeding with the network setup.

### Initial configuration
Configure the environment according to your specific requirements by editing the `network.config` file. This configuration file contains all the necessary variables for the network configuration, including the Hyperledger Fabric version being used, the default identities and the chaincode parameters.


### Initial setup
The initial setup might be a little tricky, since it requires strict cooperation and coordination among all the initial members of the network. Firstly, a leader organization is choosen among the participants: this ensures that critical operations are executed only once. 

**NOTES**
- All the scripts are path sensitive, so navigate to the `scripts/` folder and execute them from it.

```bash
cd network/scripts
```

- As of now, identities must be specified as parameters (i.e. organization and orderer domains), due to the limitations of executing the entire testbed in a single host environment. In production, this will be removed and replaced instead with the ones defined in the `network.config`.

Before starting, ensure that Hyperledger Fabric binaries (i.e. `bin/` folder) and required libraries (e.g. `yq` and `jq`) are available. If not, just run the following command to download them:

```bash
./install-requirements.sh
```

**1. Package the chaincode (admin only)**
After defining the chaincode, in order to be installed and executed by all the peers of the network, in need to be packaged as a .tar.gz file. This can be done with the following commands:

```bash
./chaincode-package.sh
```

This allows the Hyperledger peer binary to package the chaincode using the environment variables defined before in the `network.config` file.

**2. Crypto and identity preparation**
This is the crucial part of this initial setup. In this phase, every organization in the network needs to generate its own crypto materials using the provided `crypto-config-file`. To increase trust among the participants, this operation is performed locally by each member. After this operation, in order to make the system works, all the CA/TLS certificates (thus excluding private keys) are used alonside the `docker-compose-file` to generate a public identity, which is saved under the `identities/` folder and shared with everyone. This process can be carried out using the following command:

```bash
./network-prep.sh <crypto-config-file> <docker-compose-file>
```

During this step, also a `endpoint.json` file is created for each public identity. This facilitates the sharing of endpoints information to all the participants of the network.

**3. Genesis block generation (admin only)**
This is the last step for the initial setup, where the leader uses all the shared identities and the `configtx.yaml` to generate the `genesis.block` file inside the `channel/` folder. 

```bash
./network-init.sh
```

This block represents the initial state of the network and it is used for the channel creation or whenever an organization needs to join. For this reason, this artifacts must be shared with all participants.

### General flow of usage
Every participant of the network will receive from the leader the `crypto-config-file` and `docker-compose-file`. As seen before, these are used in the initial setup to generate the private credentials and the relative public identity. 

**1. Start the containers**
After receiving all the material from the leader organization, each organization needs to start its services:

```bash
./docker-up.sh <docker-compose-file>
```

**2. Join the network**
Every organizations (both orderers and peers) need to join the channel created using the `genesis.block` before. This can be done with the following:

```bash
./network-join-orderer.sh <orderer-domain> (if orderer)
./network-join-organization.sh <organization-domain> (if organization)
```

**2. Install the chaincode**
In order to make the chaincode accessible and executable, each peer that is willing to endorse its operations must install it. For simplicity, this installation process is performed on all the peers defining an organization. 

```bash
./chaincode-install.sh <organization-domain>
```

Of course installing it doesn't mean that we can directly use it. Before doing so, the chaincode definition must be committed into the channel. This operation requires each organization to approve it, otherwise the channel policies will block the operation. This can be done with:

```bash
./chaincode-approve.sh <organization-domain>
```

Finally, after receveiving the majority of approvements, the chaincode can be committed only once to the channel by any organization:

```bash
./chaincode-commit.sh <organization-domain>
```

If all these operations are successfully carried out, then the chaincode can be invoked or queried:

```bash
./chaincode-invoke.sh <organization-domain>
```

### Adding a new organization to the network
If a new organization is willing to join the network, then it must generate its public identity and own credentials:

```bash
./network-prep.sh <new-org-crypto-config-file> <new-org-docker-compose-file>
```

Then, it must share the public identity with all the other organizations in the network. After this operation, it needs to bring up its services using:

```bash
./docker-up.sh <new-org-docker-compose-file>
```

Meanwhile, all the other participants need somehow to approve the new organization in the system. To do so, one of them needs to create a joining request, which it's then shared as artifact in the `channel/` folder. This process can be done with:

```bash
./network-join-request.sh <new-org-configtx-file> <organization-domain>
```

Then, this request must be signed by all the participants of the network, using the following command:

```bash
./network-approve-update.sh <channel/joining-request.pb> <organization-domain>
```

Finally, a single organization can commit this request to the channel, allowing the channel configuration changes to welcome the new organization:

```bash
./network-commit-update.sh <joining-request.pb> <organization-domain>
```

After this operation, the new organization is finally a member of the network. Thus, as before, it can simply join the channel using:

```bash
./network-join-organization.sh <new-organization-domain>
```

At this point, the new organization requires to perform an additional update into the channel: it needs to set at least one anchor peer to make the gossip protocol work properly. This can be done with:

```bash
./network-set-achor-peer.sh <new-organization-domain>
```

Now, in order to allows the execution of the chaincode also on the peers of the new organization, the complete installation process of the chaincode must be repeated. So the chaincode is installed only on the new organization using: 

```bash
./chaincode-install.sh <new-organization-domain>
```

Then, the chaincode is again validated and approved by all the members of the network:

```bash
./chaincode-approve.sh <organization-domain> 
```

And finally, the chaincode is committed on the channel with:


```bash
./chaincode-commit.sh <organization-domain> 
```

### Removing an organization from the network
Removing an organization from the channel as a specular process of the adding one. So an organizaiton needs to create a leave request using the following command:

```bash
./network-leave-request.sh <org-configtx-file> <organization-domain>
```

Then, this request must be signed by the majority of the remaining organization in the network. After this, the update can be committed and the information about the removed organization are deleted from the channel config. Next, the organization that is leaving, must delete its public identity and optionally its private creadentials: this is done to ensure consistency in the system.

```bash
./network-leave-organization.sh <organization-domain>
```

Finally, it can stop its services using the:

```bash
./docker-down.sh <org-compose-file>
```


## Node.js Application

### Installation

1. **Navigate to the application directory:**
   ```bash
   cd node-app
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

### Running the Application

**Start the application:**
```bash
npm run start
```

### Development

**If TypeScript files are modified, rebuild before starting:**
```bash
npm run build
npm run start
```
