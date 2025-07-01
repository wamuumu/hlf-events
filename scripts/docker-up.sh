#!/bin/bash

# Parse command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Hyperledger Fabric Docker Network Startup Script"
    echo ""
    echo "This script starts the Fabric network using Docker Compose:"
    echo ""
    echo "✓ Validates prerequisites and configuration"
    echo "✓ Detects correct docker-compose file"
    echo "✓ Starts network containers with proper settings"
    echo "✓ Provides network status information"
    echo ""
    echo "Prerequisites:"
    echo "  - Docker and Docker Compose installed"
    echo "  - Network configuration in config directory"
    echo "  - Crypto material generated (./create-crypto.sh)"
    echo ""
    echo "Usage:"
    echo "  ./docker-up.sh                     # Start network with default settings"
    echo "  ./docker-up.sh --help              # Show this help message"
    echo ""
    exit 0
fi

# Set the working directory to the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Configuration
CONFIG_PATH="$PROJECT_ROOT/config"
RUNTIME_PATH="$PROJECT_ROOT/runtime"
CRYPTO_CONFIG_PATH="$RUNTIME_PATH/crypto-config"

# Try to find the docker-compose file
DOCKER_COMPOSE_FILES=(
    "$CONFIG_PATH/docker-compose.yaml"
    "$CONFIG_PATH/docker_compose_HLF.yaml"
    "$CONFIG_PATH/docker-compose.yml"
    "$PROJECT_ROOT/docker-compose.yaml"
    "$PROJECT_ROOT/docker-compose.yml"
)

DOCKER_COMPOSE_FILE=""
for file in "${DOCKER_COMPOSE_FILES[@]}"; do
    if [ -f "$file" ]; then
        DOCKER_COMPOSE_FILE="$file"
        break
    fi
done

# Project name for Docker Compose
PROJECT_NAME="hlf-events"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Hyperledger Fabric Network...${NC}"
echo "Configuration:"
echo "  - Project Root: $PROJECT_ROOT"
echo "  - Config Path: $CONFIG_PATH"
echo "  - Docker Compose: $DOCKER_COMPOSE_FILE"
echo "  - Project Name: $PROJECT_NAME"
echo ""

# Check if Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    echo -e "${YELLOW}Please install Docker from: https://docs.docker.com/get-docker/${NC}"
    exit 1
fi

if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker daemon is not running${NC}"
    echo -e "${YELLOW}Please start Docker and try again${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Docker is installed and running${NC}"

# Check if docker-compose file exists
if [ -z "$DOCKER_COMPOSE_FILE" ]; then
    echo -e "${RED}Error: Docker Compose file not found${NC}"
    echo -e "${YELLOW}Looked for:${NC}"
    for file in "${DOCKER_COMPOSE_FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

echo -e "${GREEN}✓ Found Docker Compose file: $DOCKER_COMPOSE_FILE${NC}"

# Check if crypto material exists
if [ ! -d "$CRYPTO_CONFIG_PATH" ]; then
    echo -e "${RED}Error: Crypto material not found at $CRYPTO_CONFIG_PATH${NC}"
    echo -e "${YELLOW}Please generate crypto material first:${NC}"
    echo "  ./scripts/create-crypto.sh"
    exit 1
fi

echo -e "${GREEN}✓ Crypto material found${NC}"

# Set environment variables
export COMPOSE_BAKE=true
export FABRIC_CFG_PATH="$CONFIG_PATH"

# Start the network
echo -e "${YELLOW}Starting containers...${NC}"

docker compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" up --build -d

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Containers started successfully!${NC}"
else
    echo -e "${RED}✗ Failed to start the containers!${NC}"
    exit 1
fi