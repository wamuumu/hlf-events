#!/bin/bash

# Parse command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Hyperledger Fabric Crypto Material Generation Script"
    echo ""
    echo "This script automatically generates crypto material and genesis blocks:"
    echo ""
    echo "✓ Auto-detects Fabric installation location"
    echo "✓ Generates crypto material from crypto-config.yaml"
    echo "✓ Creates genesis block from configtx.yaml"
    echo "✓ Decodes genesis block to JSON format"
    echo ""
    echo "Prerequisites:"
    echo "  - Hyperledger Fabric binaries installed"
    echo "  - jq installed for JSON processing"
    echo ""
    echo "Usage:"
    echo "  ./create-crypto.sh                                          # Use default config and channel"
    echo "  ./create-crypto.sh --help                                   # Show this help message"
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
    if [ -f "$path/cryptogen" ] && [ -f "$path/configtxgen" ]; then
        FABRIC_BIN_PATH="$path"
        break
    fi
done

# If not found in common locations, check if tools are in PATH
if [ -z "$FABRIC_BIN_PATH" ] && command -v cryptogen &> /dev/null && command -v configtxgen &> /dev/null; then
    FABRIC_BIN_PATH="$(dirname "$(which cryptogen)")"
fi

# Configuration paths
CONFIG_PATH="$PROJECT_ROOT/config"
RUNTIME_PATH="$PROJECT_ROOT/runtime"
CHANNEL_NAME="mychannel"
CRYPTO_CONFIG_PATH="$PROJECT_ROOT/config/crypto-config.yaml"
CRYPTO_OUTPUT_PATH="$RUNTIME_PATH/crypto-config"
GENESIS_BLOCK_PATH="$RUNTIME_PATH/genesis.block"
GENESIS_JSON_PATH="$RUNTIME_PATH/genesis.block.json"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Generating Hyperledger Fabric Crypto Material and Genesis Block...${NC}"
echo "Configuration:"
echo "  - Fabric Binaries: $FABRIC_BIN_PATH"
echo "  - Config Path: $CONFIG_PATH"
echo "  - Crypto Config: $CRYPTO_CONFIG_PATH"
echo "  - Channel Name: $CHANNEL_NAME"
echo "  - Crypto Output: $CRYPTO_OUTPUT_PATH"
echo "  - Genesis Block: $GENESIS_BLOCK_PATH"
echo ""

# Check if fabric binaries exist
if [ -z "$FABRIC_BIN_PATH" ]; then
    echo -e "${RED}Error: Fabric binaries not found!${NC}"
    echo -e "${YELLOW}Please ensure Hyperledger Fabric is installed in one of these locations:${NC}"
    echo "  - $HOME/fabric-samples/bin/"
    echo "  - $HOME/HLF/fabric-samples/bin/"
    echo "  - /opt/fabric/bin/"
    echo "  - /usr/local/fabric/bin/"
    echo "  - Or ensure 'cryptogen' and 'configtxgen' commands are available in your PATH"
    echo ""
    echo -e "${YELLOW}You can download Fabric from: https://hyperledger-fabric.readthedocs.io/en/latest/install.html${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found Fabric binaries at: $FABRIC_BIN_PATH${NC}"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo -e "${YELLOW}Please install jq for JSON processing:${NC}"
    echo "  - macOS: brew install jq"
    echo "  - Ubuntu/Debian: sudo apt-get install jq"
    echo "  - CentOS/RHEL: sudo yum install jq"
    exit 1
fi

echo -e "${GREEN}✓ jq is available${NC}"

# Check if crypto config file exists
if [ ! -f "$CRYPTO_CONFIG_PATH" ]; then
    echo -e "${RED}Error: Crypto config file not found at $CRYPTO_CONFIG_PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found crypto config file${NC}"

# Check if configtx.yaml exists
if [ ! -f "$CONFIG_PATH/configtx.yaml" ]; then
    echo -e "${RED}Error: configtx.yaml not found at $CONFIG_PATH/configtx.yaml${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found network config file${NC}"

# Clean and prepare runtime directory
if [ -d "$RUNTIME_PATH" ]; then
    echo -e "${YELLOW}Cleaning existing runtime directory...${NC}"
    rm -rf "$RUNTIME_PATH"/*
    echo -e "${GREEN}✓ Runtime directory cleaned${NC}"
else
    echo -e "${YELLOW}Creating runtime directory...${NC}"
    mkdir -p "$RUNTIME_PATH"
    echo -e "${GREEN}✓ Runtime directory created${NC}"
fi

# Generate crypto material
echo -e "${YELLOW}Generating crypto material...${NC}"
"$FABRIC_BIN_PATH/cryptogen" generate --config="$CRYPTO_CONFIG_PATH" --output="$CRYPTO_OUTPUT_PATH"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to generate crypto material!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Crypto material generated successfully${NC}"

# Generate genesis block
echo -e "${YELLOW}Creating genesis block for channel '$CHANNEL_NAME'...${NC}"
"$FABRIC_BIN_PATH/configtxgen" -configPath "$CONFIG_PATH" -profile ChannelUsingRaft -outputBlock "$GENESIS_BLOCK_PATH" -channelID "$CHANNEL_NAME"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to generate genesis block!${NC}"
    echo -e "${YELLOW}Make sure your configtx.yaml has a 'ChannelUsingRaft' profile defined${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Genesis block generated successfully${NC}"

# Decode genesis block to JSON
echo -e "${YELLOW}Decoding genesis block to JSON...${NC}"
if "$FABRIC_BIN_PATH/configtxlator" proto_decode --input "$GENESIS_BLOCK_PATH" --type common.Block --output "$GENESIS_JSON_PATH";  then
    echo -e "${GREEN}✓ Genesis block decoded to JSON${NC}"
else 
    echo -e "${YELLOW}⚠ Genesis block decoding failed, but core functionality completed${NC}"
fi

# Show summary
echo ""
echo "Generated files:"
echo "  📁 Crypto material: $CRYPTO_OUTPUT_PATH"
echo "  🧱 Genesis block: $GENESIS_BLOCK_PATH"
echo "  📄 Genesis JSON: $GENESIS_JSON_PATH"
echo ""

# Show directory structure
if [ -d "$CRYPTO_OUTPUT_PATH" ]; then
    CRYPTO_SIZE=$(du -sh "$CRYPTO_OUTPUT_PATH" 2>/dev/null | cut -f1)
    echo -e "${GREEN}Crypto material size: $CRYPTO_SIZE${NC}"
fi

if [ -f "$GENESIS_BLOCK_PATH" ]; then
    GENESIS_SIZE=$(du -h "$GENESIS_BLOCK_PATH" | cut -f1)
    echo -e "${GREEN}Genesis block size: $GENESIS_SIZE${NC}"
fi