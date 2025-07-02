#!/bin/bash

# Function to show help
show_help() {
    echo "Hyperledger Fabric Chaincode Execution Script"
    echo ""
    echo "This script invokes and queries chaincode functions:"
    echo ""
    echo "✓ Validates prerequisites and chaincode status"
    echo "✓ Executes chaincode functions (invoke/query)"
    echo "✓ Provides formatted output and error handling"
    echo "✓ Supports multiple chaincode operations"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker containers running (./docker-up.sh)"
    echo "  - Network channels setup (./network-up.sh)" 
    echo "  - Chaincode installed and committed (./install-chaincode.sh)"
    echo ""
    echo "Usage:"
    echo "  ./run-chaincode.sh -c <chaincode-name> [-n <channel-name>]"
    echo "  ./run-chaincode.sh -c publishProv                    # Invoke sample function"
    echo "  ./run-chaincode.sh -c readProv                       # Query sample function"
    echo "  ./run-chaincode.sh -c publishProv -n mychannel       # Custom channel"
    echo "  ./run-chaincode.sh --help                            # Show this help message"
    echo ""
    echo "Available chaincode operations:"
    echo "  publishProv   - Invoke HLF_CreateProv function (creates provenance record)"
    echo "  readProv      - Query HLF_ReadProv function (reads provenance record)"
    echo "  list          - Show all available operations"
    echo ""
}

# Parse command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_help
    exit 0
fi

# Initialize variables
CHANNEL_NAME="mychannel"
CHAINCODE_NAME=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--chaincode)
            CHAINCODE_NAME="$2"
            shift 2
            ;;
        -n|--channel)
            CHANNEL_NAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set the working directory to the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="hlf-events"
ORDERER1="orderer1.ord.testbed.local:7050"
PEER_ORG1="peer0.org1.testbed.local:7051"
PEER_ORG2="peer0.org2.testbed.local:7051"

# Validate required parameters
if [ -z "$CHAINCODE_NAME" ]; then
    echo -e "${RED}Error: Chaincode name is required${NC}"
    echo "Use: ./run-chaincode.sh -c <chaincode-name>"
    echo "Use --help for more information"
    exit 1
fi

echo -e "${YELLOW}Executing Hyperledger Fabric Chaincode...${NC}"
echo "Configuration:"
echo "  - Project Root: $PROJECT_ROOT"
echo "  - Channel Name: $CHANNEL_NAME"
echo "  - Chaincode Operation: $CHAINCODE_NAME"
echo "  - Orderer: $ORDERER1"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

# Check if Docker is running
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    echo -e "${YELLOW}Please start Docker and try again${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is running${NC}"

# Check for jq (optional but helpful for JSON formatting)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠ jq not found - JSON output will not be formatted${NC}"
    echo -e "${CYAN}💡 Install jq for better JSON formatting: brew install jq${NC}"
else
    echo -e "${GREEN}✓ jq is available for JSON formatting${NC}"
fi

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

# Check if chaincode is installed and committed
echo -e "${YELLOW}Checking chaincode status...${NC}"
CHAINCODE_STATUS=$(docker exec peer0.org1.testbed.local bash -c "
    export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/users/Admin@org1.testbed.local/msp/ && 
    peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME --name publishProv 2>/dev/null
" 2>/dev/null)

if [ $? -eq 0 ] && [[ "$CHAINCODE_STATUS" == *"publishProv"* ]]; then
    echo -e "${GREEN}✓ Chaincode 'publishProv' is committed on channel '$CHANNEL_NAME'${NC}"
else
    echo -e "${RED}Error: Chaincode 'publishProv' is not committed on channel '$CHANNEL_NAME'${NC}"
    echo -e "${YELLOW}Please install and commit the chaincode first:${NC}"
    echo "  ./scripts/install-chaincode.sh"
    exit 1
fi

# Function to invoke chaincode (create provenance)
invoke_publish_prov() {
    echo -e "${BLUE}Invoking chaincode function: HLF_CreateProv${NC}"
    echo -e "${CYAN}Creating sample provenance record...${NC}"
    
    TIMESTAMP=$(date +%s)
    PID="pid_$(date +%Y%m%d_%H%M%S)"
    URI="https://example.com/resource/$PID"
    
    # Generate hash - use shasum on macOS, sha256sum on Linux
    if command -v sha256sum &> /dev/null; then
        HASH=$(echo -n "$PID$URI$TIMESTAMP" | sha256sum | cut -d' ' -f1)
    elif command -v shasum &> /dev/null; then
        HASH=$(echo -n "$PID$URI$TIMESTAMP" | shasum -a 256 | cut -d' ' -f1)
    else
        # Fallback to a simple hash
        HASH=$(echo -n "$PID$URI$TIMESTAMP" | od -An -tx1 | tr -d ' \n')
    fi
    
    echo "Parameters:"
    echo "  - PID: $PID"
    echo "  - URI: $URI"
    echo "  - Hash: $HASH"
    echo "  - Timestamp: $TIMESTAMP"
    echo "  - Owners: [\"owner1\", \"owner2\"]"
    echo ""
    
    echo -e "${YELLOW}Executing transaction...${NC}"
    
    # Construct the JSON payload properly
    JSON_PAYLOAD="{\"Function\":\"HLF_CreateProv\",\"Args\":[\"$PID\",\"$URI\",\"$HASH\",\"$TIMESTAMP\",\"[\\\"owner1\\\",\\\"owner2\\\"]\"]}"
    
    # Execute the command
    RESULT=$(docker exec -e PID="$PID" -e URI="$URI" -e HASH="$HASH" -e TIMESTAMP="$TIMESTAMP" \
        peer0.org1.testbed.local bash -c "
        export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/users/Admin@org1.testbed.local/msp/ && 
        peer chaincode invoke \
            -o $ORDERER1 \
            -C $CHANNEL_NAME \
            -n publishProv \
            --tls \
            --cafile /etc/hyperledger/fabric/ordererOrganizations/ord.testbed.local/tlsca/tlsca.ord.testbed.local-cert.pem \
            --peerAddresses $PEER_ORG1 \
            --tlsRootCertFiles /etc/hyperledger/fabric/tlsca/tlsca.org1.testbed.local-cert.pem \
            --peerAddresses $PEER_ORG2 \
            --tlsRootCertFiles /etc/hyperledger/fabric/peerOrganizations/org2.testbed.local/peers/peer0.org2.testbed.local/msp/tlscacerts/tlsca.org2.testbed.local-cert.pem \
            -c '{\"Function\":\"HLF_CreateProv\",\"Args\":[\"'\$PID'\",\"'\$URI'\",\"'\$HASH'\",\"'\$TIMESTAMP'\",\"[\\\"owner1\\\",\\\"owner2\\\"]\"]}'
    " 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Transaction successful!${NC}"
        echo -e "${BLUE}Response:${NC}"
        if [ -n "$RESULT" ]; then
            echo "$RESULT"
        else
            echo -e "${YELLOW}(No response data)${NC}"
        fi
    else
        echo -e "${RED}✗ Transaction failed!${NC}"
        echo -e "${YELLOW}Error details:${NC}"
        echo "$RESULT"
        return 1
    fi
}

# Function to query chaincode (read provenance)
query_read_prov() {
    echo -e "${BLUE}Querying chaincode function: HLF_ReadProv${NC}"
    echo -e "${CYAN}Reading provenance record...${NC}"
    
    # Use a sample PID that matches our creation pattern - in practice, this should be parameterized
    # For demonstration, we'll use a test PID. In production, this should accept a PID parameter
    PID="pid_20250702_135347"  # Using the PID from our test creation
    
    echo "Parameters:"
    echo "  - PID: $PID"
    echo ""
    echo -e "${YELLOW}💡 Note: Using test PID '$PID'. For production use, consider adding PID parameter support.${NC}"
    echo -e "${CYAN}💡 To query a specific record, modify the PID variable in the script or add parameter support.${NC}"
    echo ""
    
    echo -e "${YELLOW}Executing query...${NC}"
    RESULT=$(docker exec -e PID="$PID" peer0.org1.testbed.local bash -c "
        export CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/users/User1@org1.testbed.local/msp/ && 
        peer chaincode query \
            -C $CHANNEL_NAME \
            -n publishProv \
            -c '{\"Function\":\"HLF_ReadProv\",\"Args\":[\"'\$PID'\"]}'
    " 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Query successful!${NC}"
        echo -e "${BLUE}Response:${NC}"
        if [ -n "$RESULT" ]; then
            echo "$RESULT"
            
            # Try to format JSON if it's valid JSON
            if echo "$RESULT" | jq . >/dev/null 2>&1; then
                echo ""
                echo -e "${CYAN}Formatted JSON:${NC}"
                echo "$RESULT" | jq .
            fi
        else
            echo -e "${YELLOW}(No response data)${NC}"
        fi
    else
        echo -e "${RED}✗ Query failed!${NC}"
        echo -e "${YELLOW}Error details:${NC}"
        echo "$RESULT"
        
        if [[ "$RESULT" == *"does not exist"* ]] || [[ "$RESULT" == *"not found"* ]]; then
            echo ""
            echo -e "${CYAN}💡 The record may not exist. Try creating one first:${NC}"
            echo "  ./run-chaincode.sh -c publishProv"
        fi
        return 1
    fi
}

# Function to show available operations
show_operations() {
    echo -e "${BLUE}Available chaincode operations:${NC}"
    echo ""
    echo -e "${CYAN}publishProv${NC} - Create provenance record"
    echo "  Function: HLF_CreateProv"
    echo "  Type: Invoke (modifies ledger)"
    echo "  Description: Creates a new provenance record with PID, URI, hash, timestamp, and owners"
    echo ""
    echo -e "${CYAN}readProv${NC} - Read provenance record"
    echo "  Function: HLF_ReadProv"
    echo "  Type: Query (read-only)"
    echo "  Description: Retrieves an existing provenance record by PID"
    echo ""
}

# Main execution based on chaincode operation
case $CHAINCODE_NAME in
    publishProv)
        invoke_publish_prov
        ;;
    readProv)
        query_read_prov
        ;;
    list|operations)
        show_operations
        ;;
    *)
        echo -e "${RED}Error: Unknown chaincode operation '$CHAINCODE_NAME'${NC}"
        echo ""
        show_operations
        echo -e "${YELLOW}Usage:${NC}"
        echo "  ./run-chaincode.sh -c publishProv"
        echo "  ./run-chaincode.sh -c readProv"
        echo "  ./run-chaincode.sh -c list"
        exit 1
        ;;
esac

