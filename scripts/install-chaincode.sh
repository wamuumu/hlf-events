#!/bin/bash

# Parse command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Hyperledger Fabric Chaincode Installation Script"
    echo ""
    echo "This script installs, approves, and commits chaincode:"
    echo ""
    echo "✓ Installs chaincode on all peer nodes"
    echo "✓ Approves chaincode for all organizations"
    echo "✓ Commits chaincode to the channel"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker containers running (./docker-up.sh)"
    echo "  - Network channels setup (./network-up.sh)"
    echo "  - Chaincode package available (./package-chaincode.sh)"
    echo ""
    echo "Usage:"
    echo "  ./install-chaincode.sh                     # Use default channel name (mychannel)"
    echo "  ./install-chaincode.sh <channel-name>      # Use custom channel name"
    echo "  ./install-chaincode.sh --help              # Show this help message"
    echo ""
    exit 0
fi

# Set the working directory to the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Parse channel name
if [ -z "$1" ]; then
    CHANNEL_NAME="mychannel"
else
    CHANNEL_NAME="$1"
fi

# Configuration
CHAINCODE_PATH="$PROJECT_ROOT/chaincode"
CHAINCODE_PACKAGE="publishv3.tar.gz"
CHAINCODE_PACKAGE_PATH="$CHAINCODE_PATH/$CHAINCODE_PACKAGE"
CHAINCODE_NAME="publishProv"
CHAINCODE_VERSION="1.0"
CHAINCODE_SEQUENCE="1"
CHAINCODE_LABEL="publishProv2.0"

# Network configuration
PROJECT_NAME="hlf-events"
ORDERER1="orderer1.ord.testbed.local:7050"
ORDERER2="orderer2.ord.testbed.local:7050"

# Peer containers and organizations
PEERS=(
    "peer0.org1.testbed.local"
    "peer0.org2.testbed.local"
    "peer0.org3.testbed.local"
)

ORGS=(
    "org1"
    "org2"
    "org3"
)

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Installing Hyperledger Fabric Chaincode...${NC}"
echo "Configuration:"
echo "  - Project Root: $PROJECT_ROOT"
echo "  - Channel Name: $CHANNEL_NAME"
echo "  - Chaincode Package: $CHAINCODE_PACKAGE_PATH"
echo "  - Chaincode Name: $CHAINCODE_NAME"
echo "  - Version: $CHAINCODE_VERSION"
echo "  - Sequence: $CHAINCODE_SEQUENCE"
echo "  - Peers: ${PEERS[*]}"
echo ""

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

# Check if chaincode package exists
if [ ! -f "$CHAINCODE_PACKAGE_PATH" ]; then
    echo -e "${RED}Error: Chaincode package not found at $CHAINCODE_PACKAGE_PATH${NC}"
    echo -e "${YELLOW}Please package the chaincode first:${NC}"
    echo "  ./scripts/package-chaincode.sh"
    exit 1
fi

echo -e "${GREEN}✓ Chaincode package found${NC}"

# Check if containers are running
echo -e "${YELLOW}Checking container status...${NC}"
RUNNING_CONTAINERS=$(docker ps --format "table {{.Names}}" | grep -E "(orderer|peer)" | wc -l)

if [ "$RUNNING_CONTAINERS" -lt 5 ]; then
    echo -e "${RED}Error: Not all containers are running (found $RUNNING_CONTAINERS)${NC}"
    echo -e "${YELLOW}Please start the network first:${NC}"
    echo "  ./scripts/docker-up.sh"
    echo "  ./scripts/network-up.sh"
    exit 1
fi

echo -e "${GREEN}✓ All containers are running ($RUNNING_CONTAINERS found)${NC}"

# Function to install chaincode on a peer
install_chaincode_on_peer() {
    local peer_name=$1
    local org_name=$2
    
    echo -e "${YELLOW}Installing chaincode on $peer_name...${NC}"
    
    docker exec "$peer_name" bash -c "
        export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/users/Admin@${org_name}.testbed.local/msp/ && 
        peer lifecycle chaincode install /var/hyperledger/chaincode_source/$CHAINCODE_PACKAGE
    "
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Chaincode installed successfully on $peer_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to install chaincode on $peer_name${NC}"
        return 1
    fi
}

# Function to get chaincode package ID
get_package_id() {
    local peer_name=$1
    local org_name=$2
    
    echo -e "${YELLOW}Getting package ID from $peer_name...${NC}"
    
    PACKAGE_ID=$(docker exec "$peer_name" bash -c "
        export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/users/Admin@${org_name}.testbed.local/msp/ && 
        peer lifecycle chaincode queryinstalled --output json 2>/dev/null | jq -r \".installed_chaincodes[] | select(.label==\\\"$CHAINCODE_LABEL\\\") | .package_id\"
    " 2>/dev/null)
    
    if [ ! -z "$PACKAGE_ID" ] && [ "$PACKAGE_ID" != "null" ]; then
        echo -e "${GREEN}✓ Package ID: $PACKAGE_ID${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to get package ID from $peer_name${NC}"
        return 1
    fi
}

# Function to approve chaincode for an organization
approve_chaincode_for_org() {
    local peer_name=$1
    local org_name=$2
    local orderer=$3
    
    echo -e "${YELLOW}Approving chaincode for $org_name on $peer_name...${NC}"
    
    docker exec "$peer_name" bash -c "
        export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/users/Admin@${org_name}.testbed.local/msp/ && 
        peer lifecycle chaincode approveformyorg \
            -o $orderer \
            --channelID $CHANNEL_NAME \
            --name $CHAINCODE_NAME \
            --version $CHAINCODE_VERSION \
            --package-id $PACKAGE_ID \
            --sequence $CHAINCODE_SEQUENCE \
            --tls \
            --cafile /etc/hyperledger/fabric/ordererOrganizations/ord.testbed.local/tlsca/tlsca.ord.testbed.local-cert.pem
    "
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Chaincode approved successfully for $org_name${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to approve chaincode for $org_name${NC}"
        return 1
    fi
}

# Function to commit chaincode
commit_chaincode() {
    local peer_name=$1
    local org_name=$2
    
    echo -e "${YELLOW}Committing chaincode from $peer_name...${NC}"
    
    # Build peer addresses and TLS cert files for all peers
    PEER_ADDRESSES=""
    TLS_ROOT_CERT_FILES=""
    
    for i in "${!PEERS[@]}"; do
        local peer="${PEERS[$i]}"
        local org="${ORGS[$i]}"
        
        if [ ! -z "$PEER_ADDRESSES" ]; then
            PEER_ADDRESSES="$PEER_ADDRESSES --peerAddresses $peer:7051"
            TLS_ROOT_CERT_FILES="$TLS_ROOT_CERT_FILES --tlsRootCertFiles /etc/hyperledger/fabric/peerOrganizations/${org}.testbed.local/peers/$peer/msp/tlscacerts/tlsca.${org}.testbed.local-cert.pem"
        else
            PEER_ADDRESSES="--peerAddresses $peer:7051"
            TLS_ROOT_CERT_FILES="--tlsRootCertFiles /etc/hyperledger/fabric/peerOrganizations/${org}.testbed.local/peers/$peer/msp/tlscacerts/tlsca.${org}.testbed.local-cert.pem"
        fi
    done
    
    docker exec "$peer_name" bash -c "
        export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/users/Admin@${org_name}.testbed.local/msp/ && 
        peer lifecycle chaincode commit \
            -o $ORDERER1 \
            --channelID $CHANNEL_NAME \
            --name $CHAINCODE_NAME \
            --version $CHAINCODE_VERSION \
            --sequence $CHAINCODE_SEQUENCE \
            --tls \
            --cafile /etc/hyperledger/fabric/ordererOrganizations/ord.testbed.local/tlsca/tlsca.ord.testbed.local-cert.pem \
            $PEER_ADDRESSES \
            $TLS_ROOT_CERT_FILES
    "
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Chaincode committed successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to commit chaincode${NC}"
        return 1
    fi
}

# Function to wait for user input
wait_for_user() {
    local message="$1"
    echo ""
    echo -e "${BLUE}$message${NC}"
    read -p "Press Enter to continue..."
    echo ""
}

# Main execution
echo -e "${YELLOW}Starting chaincode installation process...${NC}"
echo ""

# Phase 1: Install chaincode on all peers
echo -e "${BLUE}Phase 1: Installing chaincode on all peers${NC}"
FAILED_INSTALLS=()

for i in "${!PEERS[@]}"; do
    peer="${PEERS[$i]}"
    org="${ORGS[$i]}"
    install_chaincode_on_peer "$peer" "$org"
done

# Phase 2: Get package ID
echo -e "${BLUE}Phase 2: Getting chaincode package ID${NC}"
if ! get_package_id "${PEERS[0]}" "${ORGS[0]}"; then
    echo -e "${RED}Failed to get package ID. Exiting.${NC}"
    exit 1
fi

# Phase 3: Approve chaincode for all organizations
echo -e "${BLUE}Phase 3: Approving chaincode for all organizations${NC}"

for i in "${!PEERS[@]}"; do
    peer="${PEERS[$i]}"
    org="${ORGS[$i]}"
    orderer="$ORDERER2"  # Use orderer2 for approvals
    
    approve_chaincode_for_org "$peer" "$org" "$orderer";
done

# Phase 4: Commit chaincode
echo -e "${BLUE}Phase 4: Committing chaincode to the channel${NC}"
if ! commit_chaincode "${PEERS[0]}" "${ORGS[0]}"; then
    echo -e "${RED}Failed to commit chaincode. Exiting.${NC}"
    exit 1
fi