<div align="center">

# 🔗 Hyperledger Fabric Dynamic Network

### *A comprehensive blockchain network implementation with real-time event monitoring and dynamic organization management*

[![Hyperledger Fabric](https://img.shields.io/badge/Hyperledger%20Fabric-2.5.13-orange?style=for-the-badge&logo=hyperledger)](https://www.hyperledger.org/use/fabric)
[![Node.js](https://img.shields.io/badge/Node.js-18+-green?style=for-the-badge&logo=node.js)](https://nodejs.org/)
[![Docker](https://img.shields.io/badge/Docker-Latest-2496ED?style=for-the-badge&logo=docker)](https://www.docker.com/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.4-3178C6?style=for-the-badge&logo=typescript)](https://www.typescriptlang.org/)
[![License](https://img.shields.io/badge/License-GPL%20v3-yellow?style=for-the-badge)](LICENSE)

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

Ensure you have the following installed:

| Tool | Version | Purpose |
|------|---------|---------|
| 🐳 [Docker](https://www.docker.com/) | Latest | Container runtime |
| 📦 [Node.js](https://nodejs.org/) | 18+ | Application runtime |
| 🔧 npm | Latest | Package manager |

### Installation

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
├── 📁 bin/                    # Hyperledger Fabric binaries
├── 📁 channel/                # Generated channel artifacts
├── 📁 compose/                # Docker Compose files
│   ├── docker-compose-ord1.yaml
│   ├── docker-compose-org1.yaml
│   └── ...
├── 📁 config/                 # Core configuration files
│   ├── core.yaml             # Peer configuration
│   └── orderer.yaml          # Orderer configuration
├── 📁 configtx/              # Channel configuration
│   ├── configtx.yaml         # Main channel config
│   └── org4/                 # Dynamic org configs
├── 📁 crypto/                # Crypto config templates
├── 📁 identities/            # Public certificates (shared)
├── 📁 organizations/         # Private keys (local only)
├── 📁 scripts/               # Automation scripts
└── 📁 caliper/               # Performance benchmarking
```

---

### ⚙️ Configuration

### Network Configuration (`network.config`)

Key parameters for customizing your deployment:

```bash
# Fabric Version
FABRIC_VERSION="2.5.13"

# Network Identifiers
NETWORK_CHN_NAME="mychannel"
DEFAULT_ORG_DOMAIN="org1.testbed.local"

# Chaincode Settings
CC_NAME="cc-test"
CC_VERSION="1.0"
CC_SRC_LANG="javascript"
```

---

## 🔧 Network Operations

All scripts must be executed from the `network/scripts/` directory.

### Initial Network Setup

```bash
# Install Hyperledger Fabric binaries and dependencies
cd network/scripts
./install-requirements.sh

# 1️⃣ Generate cryptographic material for each organization
./network-prep.sh <crypto-config-file> <docker-compose-file>

# 2️⃣ Generate genesis block (admin only)
./network-init.sh

# 3️⃣ Start Docker containers
./docker-up.sh <docker-compose-file>

# 4️⃣ Join orderers and organizations to the channel
./network-join-orderer.sh <orderer-hostname>
./network-join-organization.sh <org-domain>
```

### Chaincode Lifecycle

```bash
# Install chaincode on organization's peers
./chaincode-install.sh <org-domain>

# Approve chaincode (each organization)
./chaincode-approve.sh <org-domain>

# Commit chaincode to channel (once)
./chaincode-commit.sh <org-domain>

# Test chaincode operations (optional)
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

### Test the network with basic setups

* **3 Ordering Nodes** (Raft consensus)
* **3 Peer Organizations** (dynamically manageable)
* **1 Application Channel** (`mychannel`)
* **1 Deployed Chaincode** (`cc-test`)
* **Full chaincode lifecycle automation**
* **Dynamic organization join/leave support**

```bash
./test-3-orgs.sh
```

```mermaid
graph TB
    subgraph Clients["Client Applications"]
        APP1[Application 1]
        APP2[Application 2]
        APP3[Application 3]
    end

    subgraph Org1["Organization 1"]
        P1[Peer0<br/>Ledger L1<br/>Chaincode: cc-test]
        P2[Peer1<br/>Ledger L1<br/>Chaincode: cc-test]
    end

    subgraph Org2["Organization 2"]
        P3[Peer0<br/>Ledger L1<br/>Chaincode: cc-test]
        P4[Peer1<br/>Ledger L1<br/>Chaincode: cc-test]
    end

    subgraph Org3["Organization 3"]
        P5[Peer0<br/>Ledger L1<br/>Chaincode: cc-test]
        P6[Peer1<br/>Ledger L1<br/>Chaincode: cc-test]
    end

    subgraph Channel["Channel: mychannel"]
        CH[Channel Configuration]
    end

    subgraph Ordering["Ordering Service (Raft)"]
        O1[Orderer 1]
        O2[Orderer 2]
        O3[Orderer 3]
    end

    APP1 -->|1. Propose Transaction| P1
    APP2 -->|1. Propose Transaction| P3
    APP3 -->|1. Propose Transaction| P5

    P1 -->|2. Endorsed Response| APP1
    P3 -->|2. Endorsed Response| APP2
    P5 -->|2. Endorsed Response| APP3

    APP1 -->|3. Submit to Ordering| Ordering
    APP2 -->|3. Submit to Ordering| Ordering
    APP3 -->|3. Submit to Ordering| Ordering

    Ordering -->|4. Deliver Blocks| Channel

    Channel -->|5. Update Ledger| Org1
    Channel -->|5. Update Ledger| Org2
    Channel -->|5. Update Ledger| Org3

    style Org1 fill:#e1f5ff
    style Org2 fill:#e8f5e9
    style Org3 fill:#fff3e0
    style Ordering fill:#ffebee
    style Channel fill:#fff9c4
    style Clients fill:#f3e5f5
```
---

## 🛡️ Security Considerations

- 🔐 **Private keys** stored locally in `organizations/` (never shared)
- 📜 **Public certificates** shared via `identities/` folder (identity verification)
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

## 📚 Additional Resources

- 📖 [Hyperledger Fabric Documentation](https://hyperledger-fabric.readthedocs.io/)
- 🔧 [Fabric Gateway SDK](https://hyperledger.github.io/fabric-gateway/)
- 📊 [Hyperledger Caliper](https://hyperledger.github.io/caliper/)

---

## 📄 License

This project is licensed under the **GNU General Public License v3** - see the [LICENSE](LICENSE) file for details.

<div align="center">

[⬆ Back to Top](#-hyperledger-fabric-dynamic-network)

</div>
