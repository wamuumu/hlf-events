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

# Generate the orderer identity to be used with set-env.sh
generate_orderer ${ORDERER_COMPOSE_FILE}

# Set the environment variables for the orderer
set_orderer_from_file ${ORD_ID_FILE}

# Join the orderer to the network
join_orderer