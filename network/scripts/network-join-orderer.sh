#!/bin/bash

. ids-utils.sh
. network-utils.sh

ORDERER_COMPOSE_FILE=$1

# Check if the orderer compose file is provided
if [ -z "$ORDERER_COMPOSE_FILE" ]; then
    echo "Usage: $0 <orderer-compose-file>"
    exit 1
fi

# Check if the file exists
if [ ! -f "$ORDERER_COMPOSE_FILE" ]; then
    echo "Error: Orderer compose file '$ORDERER_COMPOSE_FILE' does not exist"
    exit 1
fi

ORD_ID=$(extract_orderer_id ${ORDERER_COMPOSE_FILE})
if [ $? -ne 0 ]; then
    echo "Error: Failed to extract orderer ID from compose file."
    exit 1
fi

# Join the orderer to the network
join_orderer ${ORD_ID}