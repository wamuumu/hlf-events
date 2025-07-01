#!/bin/bash

# Parse command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Hyperledger Fabric Network Channel Setup Script"
    echo ""
    echo "This script sets up channels and joins network components:"
    echo ""
    echo "✓ Auto-detects Fabric installation location"
    echo "✓ Joins orderers to the channel using osnadmin"
    echo "✓ Joins peers to the channel"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker containers running (./docker-up.sh)"
    echo "  - Crypto material generated (./create-crypto.sh)"
    echo "  - Hyperledger Fabric binaries installed"
    echo ""
    echo "Usage:"
    echo "  ./join-network.sh                    # Use default channel name (mychannel)"
    echo "  ./join-network.sh <channel-name>     # Use custom channel name"
    echo "  ./join-network.sh --help             # Show this help message"
    echo ""
    exit 0
fi

# Set the working directory to the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Configuration
# Try to find Fabric binaries in common locations
FABRIC_BIN_PATHS=(
    "$HOME/fabric-samples/bin"
    "$HOME/HLF/fabric-samples/bin"
    "/opt/fabric/bin"
    "/usr/local/fabric/bin"
)

FABRIC_BIN_PATH=""
for path in "${FABRIC_BIN_PATHS[@]}"; do
    if [ -f "$path/osnadmin" ] && [ -f "$path/peer" ]; then
        FABRIC_BIN_PATH="$path"
        break
    fi
done

# If not found in common locations, check if tools are in PATH
if [ -z "$FABRIC_BIN_PATH" ] && command -v osnadmin &> /dev/null && command -v peer &> /dev/null; then
    FABRIC_BIN_PATH="$(dirname "$(which osnadmin)")"
fi

# Parse channel name
if [ -z "$1" ]; then
    CHANNEL_NAME="mychannel"
else
    CHANNEL_NAME="$1"
fi

# Configuration paths
RUNTIME_PATH="$PROJECT_ROOT/runtime"
CRYPTO_CONFIG_PATH="$RUNTIME_PATH/crypto-config"
GENESIS_BLOCK_PATH="$RUNTIME_PATH/genesis.block"

# Network configuration
ORDERER1_ADDR="localhost:7051"
ORDERER2_ADDR="localhost:8051"
PROJECT_NAME="hlf-events"

# Peer containers
PEERS=(
    "peer0.org1.testbed.local"
    "peer0.org2.testbed.local"
    "peer0.org3.testbed.local"
)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up Hyperledger Fabric Network Channel...${NC}"
echo "Configuration:"
echo "  - Project Root: $PROJECT_ROOT"
echo "  - Channel Name: $CHANNEL_NAME"
echo "  - Fabric Binaries: $FABRIC_BIN_PATH"
echo "  - Genesis Block: $GENESIS_BLOCK_PATH"
echo "  - Orderer 1: $ORDERER1_ADDR"
echo "  - Orderer 2: $ORDERER2_ADDR"
echo "  - Peers: ${PEERS[*]}"
echo ""

# Check if fabric binaries exist
if [ -z "$FABRIC_BIN_PATH" ]; then
    echo -e "${RED}Error: Fabric binaries not found!${NC}"
    echo -e "${YELLOW}Please ensure Hyperledger Fabric is installed in one of these locations:${NC}"
    echo "  - $HOME/fabric-samples/bin/"
    echo "  - $HOME/HLF/fabric-samples/bin/"
    echo "  - /opt/fabric/bin/"
    echo "  - /usr/local/fabric/bin/"
    echo "  - Or ensure 'osnadmin' and 'peer' commands are available in your PATH"
    echo ""
    echo -e "${YELLOW}You can download Fabric from: https://hyperledger-fabric.readthedocs.io/en/latest/install.html${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found Fabric binaries at: $FABRIC_BIN_PATH${NC}"

# Check if Docker is running
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"

# Check if crypto material exists
if [ ! -d "$CRYPTO_CONFIG_PATH" ]; then
    echo -e "${RED}Error: Crypto material not found at $CRYPTO_CONFIG_PATH${NC}"
    echo -e "${YELLOW}Please generate crypto material first:${NC}"
    echo "  ./scripts/create-crypto.sh"
    exit 1
fi

echo -e "${GREEN}✓ Crypto material found${NC}"

# Check if genesis block exists
if [ ! -f "$GENESIS_BLOCK_PATH" ]; then
    echo -e "${RED}Error: Genesis block not found at $GENESIS_BLOCK_PATH${NC}"
    echo -e "${YELLOW}Please generate genesis block first:${NC}"
    echo "  ./scripts/create-crypto.sh"
    exit 1
fi

echo -e "${GREEN}✓ Genesis block found${NC}"

# Check if containers are running
echo -e "${YELLOW}Checking container status...${NC}"
RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}" | grep -E "(orderer|peer)" | wc -l)

if [ "$RUNNING_CONTAINERS" -lt 5 ]; then
    echo -e "${RED}Error: Not all containers are running (found $RUNNING_CONTAINERS)${NC}"
    echo -e "${YELLOW}Please start the network first:${NC}"
    echo "  docker-up.sh"
    exit 1
fi

echo -e "${GREEN}✓ All containers are running ($RUNNING_CONTAINERS found)${NC}"

# Set up paths for crypto material
ORDERER_TLS_CA="$CRYPTO_CONFIG_PATH/ordererOrganizations/ord.testbed.local/tlsca/tlsca.ord.testbed.local-cert.pem"
ORDERER1_TLS_CERT="$CRYPTO_CONFIG_PATH/ordererOrganizations/ord.testbed.local/orderers/orderer1.ord.testbed.local/tls/server.crt"
ORDERER1_TLS_KEY="$CRYPTO_CONFIG_PATH/ordererOrganizations/ord.testbed.local/orderers/orderer1.ord.testbed.local/tls/server.key"

# Function to join orderer to channel
join_orderer_to_channel() {
    local orderer_addr=$1
    local orderer_name=$2
    
    echo -e "${YELLOW}Joining $orderer_name ($orderer_addr) to channel '$CHANNEL_NAME'...${NC}"
    
    "$FABRIC_BIN_PATH/osnadmin" channel join \
        --channelID "$CHANNEL_NAME" \
        --config-block "$GENESIS_BLOCK_PATH" \
        -o "$orderer_addr" \
        --ca-file "$ORDERER_TLS_CA" \
        --client-cert "$ORDERER1_TLS_CERT" \
        --client-key "$ORDERER1_TLS_KEY"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $orderer_name joined channel successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to join $orderer_name to channel${NC}"
        return 1
    fi
}

# Function to join peer to channel
join_peer_to_channel() {
    local peer_name=$1
    local org_name=$(echo "$peer_name" | cut -d'.' -f2)
    
    echo -e "${YELLOW}Joining $peer_name to channel '$CHANNEL_NAME'...${NC}"
    
    docker exec "$peer_name" bash -c "
        export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/users/Admin@${org_name}.testbed.local/msp/ && 
        peer channel join -b /etc/hyperledger/fabric/mychannel/genesis.block \
            --tls \
            --cafile /etc/hyperledger/fabric/ordererOrganizations/ord.testbed.local/tlsca/tlsca.ord.testbed.local-cert.pem \
            --certfile /etc/hyperledger/fabric/peers/${peer_name}/tls/server.crt \
            --keyfile /etc/hyperledger/fabric/peers/${peer_name}/tls/server.key \
            -o orderer1.ord.testbed.local:7050 \
            --clientauth
    "
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $peer_name joined channel successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to join $peer_name to channel${NC}"
        return 1
    fi
}

# Main execution
echo -e "${YELLOW}Starting channel setup process...${NC}"
echo ""

# Join orderers to channel
join_orderer_to_channel "$ORDERER2_ADDR" "orderer2"
join_orderer_to_channel "$ORDERER1_ADDR" "orderer1"

# Join peers to channel
for peer in "${PEERS[@]}"; do
    join_peer_to_channel "$peer"
done

# Final summary
echo ""
echo -e "${YELLOW}Channel setup completed!${NC}"
echo ""