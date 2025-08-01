#!/bin/bash

. set-env.sh

# Docker setup
./docker-up.sh "${ORGANIZATION_COMPOSE_FILES[1]}" # Initialize the organization 2 container

# Channel setup
./network-join-organization.sh "${ORGANIZATION_COMPOSE_FILES[1]}" # Join the organization 2 to the network

# Deploy the chaincode
./chaincode-install.sh # Install the chaincode on all peers
./chaincode-approve.sh # Approve the chaincode for the organization