# Hyperledger Fabric Events

A comprehensive project demonstrating Hyperledger Fabric network setup with a Node.js application for chaincode interaction and event monitoring.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Hyperledger Fabric Network](#hyperledger-fabric-network)
- [Node.js Application](#nodejs-application)

## Prerequisites

Before running this project, ensure you have the following installed:

- **[Docker](https://www.docker.com/)** - Container platform for running the Fabric network
- **[Node.js](https://nodejs.org/)** (v18+) - JavaScript runtime for the application
- **[npm](https://www.npmjs.com/)** - Package manager for Node.js dependencies

## Getting Started

This project consists of two main components:
1. **Hyperledger Fabric Network** - The blockchain network infrastructure
2. **Node.js Application** - Client application for interacting with the network

## Hyperledger Fabric Network

### Setup and Configuration

1. **Navigate to the network directory:**
   ```bash
   cd network
   ```

2. **Configure the network:**
   - Modify the `network.config` file according to your environment settings

3. **Start the network:**
   Execute the following commands in sequence:
   ```bash
   ./generate-crypto.sh
   ./package-chaincode.sh
   ./docker-up.sh
   ./join-network.sh
   ./deploy-chaincode.sh
   ```

### Testing the Network

**Invoke a transaction from CLI:**
```bash
./invoke-chaincode.sh
```

### Stopping the Network

**To stop and clean up the network:**
```bash
./docker-down.sh
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
