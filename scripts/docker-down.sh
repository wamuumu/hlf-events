#!/bin/bash

# Parse command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
            echo "Hyperledger Fabric Docker Network Shutdown Script"
            echo ""
            echo "This script stops and removes the Fabric network using Docker Compose:"
            echo ""
            echo "✓ Validates prerequisites and configuration"
            echo "✓ Detects correct docker compose file"
            echo "✓ Stops network containers with aggressive cleanup"
            echo "✓ Removes volumes and orphaned containers"
            echo "✓ Prunes unused Docker resources"
            echo ""
            echo "Prerequisites:"
            echo "  - Docker installed"
            echo "  - Containers configuration in config directory"
            echo ""
            echo "Usage:"
            echo "  ./docker-down.sh                   # Stop network with cleanup"
            echo "  ./docker-down.sh --help            # Show this help message"
            echo ""
            exit 0
fi

# Set the working directory to the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Configuration
CONFIG_PATH="$PROJECT_ROOT/config"

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

echo -e "${YELLOW}Stopping Hyperledger Fabric Network...${NC}"
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

# Check if docker compose file exists
if [ -z "$DOCKER_COMPOSE_FILE" ]; then
    echo -e "${RED}Error: Docker Compose file not found${NC}"
    echo -e "${YELLOW}Looked for:${NC}"
    for file in "${DOCKER_COMPOSE_FILES[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

echo -e "${GREEN}✓ Found Docker Compose file: $DOCKER_COMPOSE_FILE${NC}"

# Check if there are any containers running for this project
RUNNING_CONTAINERS=$(docker compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" ps -q 2>/dev/null)

if [ -z "$RUNNING_CONTAINERS" ]; then
    echo -e "${YELLOW}No containers found for project '$PROJECT_NAME'${NC}"
    exit 0
else
    echo -e "${GREEN}✓ Found running containers for project '$PROJECT_NAME'${NC}"
fi

# Stop the network
echo -e "${YELLOW}Removing containers, networks, and volumes...${NC}"
docker compose -f "$DOCKER_COMPOSE_FILE" -p "$PROJECT_NAME" down --volumes --remove-orphans

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Containers and volumes removed successfully${NC}"
    
    # Additional aggressive cleanup
    echo -e "${YELLOW}Performing additional cleanup...${NC}"
    
    # Prune unused volumes
    echo -e "${YELLOW}Pruning unused Docker volumes...${NC}"
    docker volume prune -f
    
    # Prune unused networks
    echo -e "${YELLOW}Pruning unused Docker networks...${NC}"
    docker network prune -f
    
    # Remove any remaining containers with the project name
    echo -e "${YELLOW}Removing any remaining project containers...${NC}"
    REMAINING_CONTAINERS=$(docker ps -aq --filter "name=$PROJECT_NAME" 2>/dev/null)
    if [ ! -z "$REMAINING_CONTAINERS" ]; then
        docker rm -f $REMAINING_CONTAINERS
        echo -e "${GREEN}✓ Removed remaining containers${NC}"
    else
        echo -e "${BLUE}No remaining containers found${NC}"
    fi
    
    echo -e "${GREEN}✓ Containers removed successfully!${NC}"
else
    echo -e "${RED}✗ Failed to perform cleanup!${NC}"
    echo -e "${YELLOW}You may need to manually clean up containers:${NC}"
    echo "  docker ps -a"
    echo "  docker stop \$(docker ps -aq)"
    echo "  docker rm \$(docker ps -aq)"
    exit 1
fi