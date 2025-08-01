#!/bin/bash

. set-env.sh

# Docker setup
./docker-up.sh "${ORGANIZATION_COMPOSE_FILES[2]}" # Initialize the organization 3 container

# Channel setup
./network-join-organization.sh "${ORGANIZATION_COMPOSE_FILES[2]}" # Join the organization 3 to the network

# Deploy the chaincode
./chaincode-install.sh # Install the chaincode on all peers
./chaincode-approve.sh # Approve the chaincode for the organization