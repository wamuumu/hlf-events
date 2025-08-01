#!/bin/bash

. ids-utils.sh
. network-utils.sh

ORGANIZATION_COMPOSE_FILE=$1

# Check if the organization compose file is provided
if [ -z "$ORGANIZATION_COMPOSE_FILE" ]; then
    echo "Usage: $0 <organization-compose-file>"
    exit 1
fi

# Check if the file exists
if [ ! -f "$ORGANIZATION_COMPOSE_FILE" ]; then
    echo "Error: Organization compose file '$ORGANIZATION_COMPOSE_FILE' does not exist"
    exit 1
fi

# Generate the organization peers
generate_peers ${ORGANIZATION_COMPOSE_FILE}

# Join the organization to the network
join_organization