#!/bin/bash

. ids-utils.sh
. network-utils.sh

ORDERER_COMPOSE_FILE=$1
ORDERER_IDENTITY_ENV=$2

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

# Check if the orderer identity environment file is provided
if [ -z "$ORDERER_IDENTITY_ENV" ]; then
    echo "Usage: $0 <orderer-compose-file> <orderer-identity-env-file>"
    exit 1
fi

# Check if the orderer identity environment file exists
if [ ! -f "$ORDERER_IDENTITY_ENV" ]; then
    echo "Error: Orderer identity environment file '$ORDERER_IDENTITY_ENV' does not exist"
    exit 1
fi

# Generate the orderer identity to be used with set-env.sh
generate_orderer ${ORDERER_COMPOSE_FILE}

# Set the environment variables for the orderer
set_orderer_from_file ${ORDERER_IDENTITY_ENV}

# Join the orderer to the network
join_orderer