#!/bin/bash

# Parse command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Hyperledger Fabric Chaincode Packaging Script"
    echo ""
    echo "This script automatically handles Go module setup and chaincode packaging:"
    echo ""
    echo "✓ Auto-detects Fabric installation location"
    echo "✓ If go.mod/go.sum don't exist: Initializes modules from scratch"
    echo "✓ If go.mod/go.sum exist: Uses existing modules and verifies dependencies"  
    echo "✓ Packages the chaincode with proper Fabric configuration"
    echo ""
    echo "Prerequisites:"
    echo "  - Go installed and available in PATH"
    echo "  - Hyperledger Fabric peer binary in standard locations"
    echo ""
    echo "Usage:"
    echo "  ./package-chaincode.sh              # Smart packaging with auto module setup"
    echo "  ./package-chaincode.sh --help       # Show this help message"
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
    if [ -f "$path/peer" ]; then
        FABRIC_BIN_PATH="$path"
        break
    fi
done

# If not found in common locations, check if peer is in PATH
if [ -z "$FABRIC_BIN_PATH" ] && command -v peer &> /dev/null; then
    FABRIC_BIN_PATH="$(dirname "$(which peer)")"
fi

# Configuration paths (relative to project root)
FABRIC_CFG_PATH="$PROJECT_ROOT/config"
CHAINCODE_PATH="$PROJECT_ROOT/chaincode/publishv3/src"
OUTPUT_PATH="$PROJECT_ROOT/chaincode/publishv3.tar.gz"
CHAINCODE_LABEL="publishProv2.0"
CHAINCODE_LANG="golang"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Packaging Hyperledger Fabric Chaincode...${NC}"
echo "Configuration:"
echo "  - Fabric Config Path: $FABRIC_CFG_PATH"
echo "  - Chaincode Path: $CHAINCODE_PATH"
echo "  - Output Path: $OUTPUT_PATH"
echo "  - Label: $CHAINCODE_LABEL"
echo "  - Language: $CHAINCODE_LANG"
echo ""

# Check if fabric binaries exist
if [ -z "$FABRIC_BIN_PATH" ] || [ ! -f "$FABRIC_BIN_PATH/peer" ]; then
    echo -e "${RED}Error: Fabric peer binary not found!${NC}"
    echo -e "${YELLOW}Please ensure Hyperledger Fabric is installed in one of these locations:${NC}"
    echo "  - $HOME/fabric-samples/bin/peer"
    echo "  - $HOME/HLF/fabric-samples/bin/peer"
    echo "  - /opt/fabric/bin/peer"
    echo "  - /usr/local/fabric/bin/peer"
    echo "  - Or ensure 'peer' command is available in your PATH"
    echo ""
    echo -e "${YELLOW}You can download Fabric from: https://hyperledger-fabric.readthedocs.io/en/latest/install.html${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found Fabric binaries at: $FABRIC_BIN_PATH${NC}"

# Check if Go is installed
if ! command -v go &> /dev/null; then
    echo -e "${RED}Error: Go is not installed or not in PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Go version: $(go version)${NC}"

# Check if config directory exists
if [ ! -d "$FABRIC_CFG_PATH" ]; then
    echo -e "${RED}Error: Config directory not found at $FABRIC_CFG_PATH${NC}"
    exit 1
fi

# Check if chaincode source exists
if [ ! -d "$CHAINCODE_PATH" ]; then
    echo -e "${RED}Error: Chaincode source directory not found at $CHAINCODE_PATH${NC}"
    exit 1
fi

# Smart Go module management
# Automatically initialize modules if go.mod/go.sum don't exist
cd "$CHAINCODE_PATH"

if [ ! -f "go.mod" ] || [ ! -f "go.sum" ]; then
    echo -e "${YELLOW}Go modules not found. Setting up Go modules...${NC}"
    
    # Remove any existing files to start fresh
    if [ -f "go.mod" ]; then
        echo -e "${YELLOW}Removing incomplete go.mod...${NC}"
        rm go.mod
    fi
    
    if [ -f "go.sum" ]; then
        echo -e "${YELLOW}Removing incomplete go.sum...${NC}"
        rm go.sum
    fi
    
    # Initialize Go module
    echo -e "${YELLOW}Initializing Go module...${NC}"
    MODULE_NAME="publishv3"
    go mod init "$MODULE_NAME"
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to initialize Go module!${NC}"
        exit 1
    fi
    
    # Tidy up dependencies
    echo -e "${YELLOW}Downloading and organizing dependencies...${NC}"
    go mod tidy
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to download dependencies!${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Go modules initialized successfully!${NC}"
else
    echo -e "${GREEN}✓ Go modules already present (go.mod and go.sum found)${NC}"
    
    # Optional: run go mod tidy to ensure dependencies are up to date
    echo -e "${YELLOW}Verifying dependencies...${NC}"
    go mod tidy
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to verify dependencies!${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Dependencies verified${NC}"
fi

# Return to project root
cd "$PROJECT_ROOT"

# Export the fabric config path
export FABRIC_CFG_PATH

# Remove existing package if it exists
if [ -f "$OUTPUT_PATH" ]; then
    echo -e "${YELLOW}Removing existing package...${NC}"
    rm "$OUTPUT_PATH"
fi

# Package the chaincode
echo -e "${YELLOW}Packaging chaincode...${NC}"
"$FABRIC_BIN_PATH/peer" lifecycle chaincode package "$OUTPUT_PATH" \
    --lang "$CHAINCODE_LANG" \
    --label "$CHAINCODE_LABEL" \
    --path "$CHAINCODE_PATH"

# Check if packaging was successful
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Chaincode packaged successfully!${NC}"
    echo -e "${GREEN}Package location: $OUTPUT_PATH${NC}"
    
    # Show package size
    if [ -f "$OUTPUT_PATH" ]; then
        PACKAGE_SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
        echo -e "${GREEN}Package size: $PACKAGE_SIZE${NC}"
    fi
else
    echo -e "${RED}✗ Chaincode packaging failed!${NC}"
    exit 1
fi
