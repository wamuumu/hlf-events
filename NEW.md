<div align="center">

# 🔗 Hyperledger Fabric Dynamic Network

### *A comprehensive permissioned blockchain network implementation with dynamic organization management, chaincode deployment and real-time event monitoring.*

[![fabric-logo]](https://hyperledger-fabric.readthedocs.io/)
[![docker-logo]](https://www.docker.com/)
[![shell-logo]](network/scripts/ "Bash scripts for network automation")
[![nodejs-logo]](https://nodejs.org/)
[![typescript-logo]](https://www.typescriptlang.org/)
[![license-logo]](LICENSE)

</div>

---

## 📋 Table of Contents

* [🚀 Getting Started](#-getting-started)
* [🧩 Project Overview](#-project-overview)
  * [🌐 Network Module](#-network-module)
  * [🧱 Chaincode Module](#-chaincode-module)
  * [💻 Node.js Application Module](#-nodejs-application-module)
* [📚 Additional Resources](#-additional-resources)
* [📄 License](#-license)

---

## 🚀 Getting Started

### Prerequisites

To run this project, ensure that all the following dependencies are installed and available: 

| Tool | Version | Purpose |
|------|---------|---------|
| 🐳 [Docker](https://www.docker.com/) | Latest | Container runtime |
| 📦 [Node.js](https://nodejs.org/) | 18+ | Application runtime |

### Installation

To get started with this project, first clone the repository to your local machine:

```bash
# Clone the repository
git clone https://github.com/wamuumu/hlf-events.git
cd hlf-events
```

---

## 🧩 Project Overview

This project consists of **three main components**, forming a complete blockchain testbed:

| Module             | Description                                                              | Folder       |
| ------------------ | ------------------------------------------------------------------------ | ------------ |
| 🌐 **Network**    | Complete Hyperledger Fabric network with dynamic organization management | `network/`   |
| 🧱 **Chaincode**   | Smart contract defining resource lifecycle operations                    | `chaincode/` |
| 💻 **Node.js App** | Event-driven TypeScript client for invoking and monitoring transactions  | `node-app/`  |

---

## 🌐 Network Module

### 📁 Folder Structure

```
network/
├── 📁 bin/                     # Hyperledger Fabric binaries
├── 📁 channel/                 # Generated channel artifacts
├── 📁 compose/                 # Docker Compose files
│   ├── docker-compose-ord1.yaml
│   ├── docker-compose-org1.yaml
│   └── ...
├── 📁 config/                  # Core configuration files
│   ├── core.yaml               # Peer configuration
│   └── orderer.yaml            # Orderer configuration
├── 📁 configtx/                # Channel configuration
│   ├── configtx.yaml            # Main channel config
│   └── 📁 org4/                # Dynamic org configs
├── 📁 crypto/                  # Crypto config templates
├── 📁 identities/              # Public certificates (shared)
├── 📁 organizations/           # Private keys (local only)
├── 📁 scripts/                 # Automation scripts
└── 📁 caliper/                 # Performance benchmarking
```

---

### ⚙️ Configuration

### Network Configuration (`network.config`)

 This configuration file contains all the necessary variables for the network definition, including the Hyperledger Fabric settings and the default identity to use. 

> [!TIP]  
> You can configure it according to your requirements.

```bash
# Fabric Version
FABRIC_VERSION="2.5.13"

# Network Identifiers
NETWORK_CHN_NAME="mychannel"
# Paths definitions ...

# Defaults variables
DEFAULT_ORG_DOMAIN="org1.tesbed.local"
DEFAULT_ORD="orderer.ord1.testbed.local"
DEFAULT_PEER_ID=1
DEFAULT_ENDPOINT="localhost"

# Chaincode Settings
CC_NAME="cc-test"
CC_SRC_LANG="javascript"
# Chaincode variables ...
```

---

## 🔧 Network Operations

> [!IMPORTANT]  
> All scripts related to network operations must be executed from the `network/scripts/` directory.

> [!NOTE]  
> In production, network operations might be a little tricky since they often require strict cooperation and coordination among all the network members.

### Initial Network Setup

> [!IMPORTANT]  
> Before proceeeding, a leader organization should be chosen, ensuring critical operations are executed only once.

#### Requirements Installation

```bash
# Install Hyperledger Fabric binaries and dependencies
cd network/scripts
./install-requirements.sh
```

> [!WARNING]  
> After the above operation, please ensure that Hyperledger Fabric binaries are available under the `network/bin` folder.

#### Cryptographic Material Generation

Each organization must generate its own credentials (private keys and public certificates) using the provided configuration files. This increases security by ensuring private keys are never shared, while public certificates are distributed via the shared `network/identities` folder.

```bash
# 1️⃣ Generate cryptographic material for each organization
./network-prep.sh <crypto-config-file> <docker-compose-file>
```
> [!IMPORTANT]  
> Crypto config files and docker compose files should be distributed by the **leader organization** and adjusted accordingly.

#### Genesis Block Generation

The leader organization is responsible for **generating** and **distributing** the genesis block, which represents the initial configuration of the network.

```bash
# 2️⃣ Generate genesis block (leader only)
./network-init.sh
```

> [!NOTE]  
> This block never changes and it is mainly used for channel creation and organization joining.

#### Containers startup and channel joining

After all organizations have generated their credentials and the genesis block has been distributed, each organization can start its Docker containers and join the channel.

```bash
# 3️⃣ Start Docker containers
./docker-up.sh <docker-compose-file>

# 4️⃣ Join orderers and organizations to the channel

# If this is an orderer organization:
./network-join-orderer.sh <orderer-hostname>

# If this is a regular organization:
./network-join-organization.sh <org-domain>
```

> [!TIP]  
> Organizations and orderers differ in their roles and responsibilities within the network.

### Chaincode Lifecycle

The chaincode defines the business logic of the blockchain application that runs on the organizations' peers. 

#### Chaincode Installation

The chaincode must be installed on all peers that will endorse transactions. This is done by packaging the chaincode in a **tarball** and then, for simplicity, installing it on each peer.

```bash
# 1️⃣ Package the chaincode 
./chaincode-package.sh

# 2️⃣ Install chaincode on organization's peers
./chaincode-install.sh <org-domain>
```

#### Chaincode Approval

Once the chaincode is installed, each organization must approve its definition. This ensures that all organizations agree on the chaincode that will be used.

```bash
# 3️⃣ Approve chaincode (each organization)
./chaincode-approve.sh <org-domain>
```

> [!IMPORTANT]  
> In order to reach consensus, all the organizations must approve the chaincode definition.

#### Chaincode Commitment

After all organizations have approved the chaincode, it can be committed to the channel. This makes the chaincode available for use in transactions.

```bash
# 4️⃣ Commit chaincode to channel (only once)
./chaincode-commit.sh <org-domain>

# 5️⃣ Test chaincode operations (optional)
./chaincode-invoke.sh <org-domain> <peer-id>
./chaincode-query.sh <org-domain> <peer-id>
```

### 🔄 Dynamic Organization Management

#### Adding a New Organization

```bash
# 1️⃣ New org: Generate credentials
./network-prep.sh crypto-config-org4.yaml docker-compose-org4.yaml

# 2️⃣ New org: Start containers
./docker-up.sh docker-compose-org4.yaml

# 3️⃣ Existing org: Create join request
./network-join-request.sh configtx-org4.yaml org1.testbed.local

# 4️⃣ All orgs: Approve join request
./network-approve-update.sh org4_update_in_envelope.pb org1.testbed.local
./network-approve-update.sh org4_update_in_envelope.pb org2.testbed.local

# 5️⃣ Any org: Commit update
./network-commit-update.sh org4_update_in_envelope.pb org1.testbed.local

# 6️⃣ New org: Join channel and set anchor peer
./network-join-organization.sh org4.testbed.local
./network-set-anchor-peer.sh org4.testbed.local 1

# 7️⃣ Install and approve chaincode
./chaincode-install.sh org4.testbed.local
./chaincode-approve.sh org4.testbed.local  # All orgs must approve
./chaincode-commit.sh org1.testbed.local   # Once
```

#### Removing an Organization

```bash
# 1️⃣ Create leave request
./network-leave-request.sh configtx-org4.yaml org4.testbed.local

# 2️⃣ Approve removal (majority required)
./network-approve-update.sh org4_update_in_envelope.pb org1.testbed.local
./network-approve-update.sh org4_update_in_envelope.pb org2.testbed.local

# 3️⃣ Commit removal
./network-commit-update.sh org4_update_in_envelope.pb org1.testbed.local

# 4️⃣ Leaving org: Clean up
./network-leave-organization.sh org4.testbed.local --hard
./docker-down.sh docker-compose-org4.yaml
```

### Test the network with basic setup

* **3 Ordering Nodes** (`Raft consensus`)
* **3 Peer Organizations**
* **1 Application Channel** (`mychannel`)
* **1 Deployed Chaincode** (`cc-test`)

```bash
# Setup a ready-to-use network with 3 organizations and 3 orderers
./test-3-orgs.sh
```

```mermaid
graph TB
    %% ============= ORGANIZATIONS =============
    subgraph Org1["🏢 Organization 1"]
        P1[Peer0.Org1<br/>Ledger<br/>Chaincode: cc-test]
    end

    subgraph Org2["🏢 Organization 2"]
        P2[Peer0.Org2<br/>Ledger<br/>Chaincode: cc-test]
    end

    subgraph Org3["🏢 Organization 3"]
        P3[Peer0.Org3<br/>Ledger<br/>Chaincode: cc-test]
    end

    %% ============= CHANNEL =============
    subgraph Channel["📡 Channel: mychannel"]
        CH[Channel Configuration Block]
    end

    %% ============= ORDERING SERVICE =============
    subgraph Ordering["🧱 Ordering Service (Raft)"]
        O1[Orderer 1]
        O2[Orderer 2]
        O3[Orderer 3]

        O1 <--> O2
        O2 <--> O3
        O3 <--> O1
    end

    %% ============= CONNECTIONS =============
    P1 --> Channel
    P2 --> Channel
    P3 --> Channel
    Channel <--> Ordering

    %% ============= STYLING =============
    style Org1 fill:#e1f5ff,stroke:#90caf9,stroke-width:1px,color:black
    style Org2 fill:#e8f5e9,stroke:#a5d6a7,stroke-width:1px,color:black
    style Org3 fill:#fff3e0,stroke:#ffcc80,stroke-width:1px,color:black
    style Channel fill:#fff9c4,stroke:#fdd835,stroke-width:1px,color:black
    style Ordering fill:#ffebee,stroke:#ef9a9a,stroke-width:1px,color:black
```
---

## 🛡️ Security Considerations

- 🔐 **Private keys** stored locally in `organizations/` (never shared)
- 📜 **Public certificates** shared via `identities/` folder (trust)
- 🔏 **TLS enabled** for all communications
- ✍️ **Digital signatures** for identity verification
- 🎫 **MSP-based** access control

---

## 📊 Performance Testing

Integrated [Hyperledger Caliper](https://hyperledger.github.io/caliper/) for comprehensive benchmarking.

### Available Benchmarks

| Benchmark | Focus | Configuration |
|-----------|-------|---------------|
| **Throughput** | Maximum TPS | 4 workers, 60s duration |
| **Latency** | Response time | 1 worker, low TPS |
| **Success Ratio** | Transaction reliability | 2 workers, mixed load |
| **Resource Usage** | CPU/Memory/Network | Docker monitoring |

### Running Benchmarks

```bash
cd network/caliper

# Configure network connection
cp networks/network-config.template.yaml networks/network-config.yaml
# Edit network-config.yaml with your organization credentials

# Run a benchmark
./run-benchmark.sh \
    networks/network-config.yaml \
    benchmarks/throughput.yaml

# Results are saved in ./results/
```

### Sample Output

```
+----------------+--------+--------+--------+--------+--------+--------+
| Name           | Succ   | Fail   | Send   | Latency| Latency| Through|
|                |        |        | Rate   | (avg)  | (max)  | put    |
+----------------+--------+--------+--------+--------+--------+--------+
| tx-throughput  | 6000   | 0      | 100.0  | 0.045  | 0.892  | 99.8   |
| query-through. | 12000  | 0      | 200.0  | 0.012  | 0.234  | 199.6  |
+----------------+--------+--------+--------+--------+--------+--------+
```

---

## 🧱 Chaincode Module

### 📁 Folder Structure

```
chaincode/
└── 📁 cc-test/                  # Chaincode folder
    ├── 📁 lib/                  # Business logic and data model definitions
    │   └── resource.js          # Chaincode source code
    ├── index.js                 # Entry point registering the smart contract
    └── package.json             # Chaincode dependencies and metadata
```

---

### Resource Events Contract

| Function | Type | Description |
|----------|------|-------------|
| `CreateResource` | Submit | Creates a new resource on the ledger |
| `ReadResource` | Evaluate | Retrieves a resource by ID |
| `ReadAllResources` | Evaluate | Returns all resources |

### Resource Schema

```javascript
{
    PID: string,           // Unique identifier
    URI: string,           // Resource location
    hash: string,          // Content hash
    timestamp: string,     // Creation time
    owners: string[]       // List of owner identifiers
}
```

## 💻 Node.js Application Module

Event-driven TypeScript application for interacting with the network.

### 📁 Folder Structure

```
node-app/
├── 📁 config/                  # Connection profiles and environment templates
│   └── connection-org1.json    # Example network connection configuration
├── 📁 src/                     # TypeScript application source code
│   ├── app.ts                  # Main entry point (application bootstrap)
│   ├── connect.ts              # ConnectionManager: gateway and connection management
│   ├── contract.ts             # ContractManager: submit/evaluate transactions
│   └── listener.ts             # EventManager: listens to chaincode and block events
├── package.json                # Project dependencies, scripts and metadata
└── tsconfig.json               # TypeScript compiler configuration

```

### Setup

```bash
cd node-app

# Install dependencies
npm install

# Configure environment
cp .env.example .env
# Edit .env with your settings

# Build and run
npm run build
npm start
```

### Application Architecture

```typescript
// Key Components
ConnectionManager (connect.ts)   →   Manages gateway connections
EventManager (listener.ts)       →   Listens to chaincode events
ContractManager (contract.ts)    →   Submits transactions
```

### Features

- ✅ **Automatic connection management** with retry logic
- ✅ **Real-time event streaming** from chaincode
- ✅ **Type-safe contract interactions**
- ✅ **Graceful shutdown handling**

### Example Usage

```typescript
// In app.ts (main)

// Create a resource
const resource = await contractManager.createResource([
    'pid_123',
    'https://example.com/resource',
    'hash_value',
    '1234567890',
    JSON.stringify(['owner1', 'owner2'])
]);

// Event automatically emitted and logged:
// <-- [CHAINCODE] Chaincode event received: CreateResource
```

---

## Acknowledgments

A big shoutout to the projects below for their awesome work and open-source contributions:

<div style="display: flex; align-items: left;">
    <a href="https://github.com/hyperledger/fabric">
        <img src="https://avatars.githubusercontent.com/u/7657900?s=200&v=4"
        alt="hyperledger" style="width: 50px; margin-right: 10px">
    </a>
    <a href="https://github.com/hyperledger-caliper/caliper">
        <img src="https://avatars.githubusercontent.com/u/185365280?s=200&v=4"
        alt="hyperledger" style="width: 50px; margin-right: 10px">
    </a>
    <a href="https://shields.io/">
        <img src="https://avatars.githubusercontent.com/u/6254238?s=200&v=4" alt="shields.io" style="width: 50px; margin-right: 10px;">
    </a>
    <a href="https://simpleicons.org/">
        <img src="https://avatars.githubusercontent.com/u/29872746?s=200&v=4" alt="simpleicons.org" style="width: 50px; margin-right: 10px;">
    </a>
</div>

---

## 📚 Additional Resources

- 📖 [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
- 🔧 [Fabric Gateway SDK](https://hyperledger.github.io/fabric-gateway/)
- 📊 [Hyperledger Caliper](https://hyperledger.github.io/caliper/)

---

## 📄 License

[![license-logo]](LICENSE)

<div align="right">

[![](https://img.shields.io/badge/Return-5D4ED3?style=flat&logo=ReadMe&logoColor=white)](#top)

</div>

<!-- LOGOs -->
[fabric-logo]: https://img.shields.io/badge/Hyperledger%20Fabric-2.5.13-orange?style=for-the-badge
[shell-logo]: https://img.shields.io/badge/Shell-Bash-4EAA25?style=for-the-badge&logo=gnu-bash
[nodejs-logo]: https://img.shields.io/badge/Node.js-18+-green?style=for-the-badge&logo=node.js
[docker-logo]: https://img.shields.io/badge/Docker-Latest-2496ED?style=for-the-badge&logo=docker
[typescript-logo]: https://img.shields.io/badge/TypeScript-5.4-3178C6?style=for-the-badge&logo=typescript
[license-logo]: https://img.shields.io/badge/License-GPL%20v3-yellow?style=for-the-badge

