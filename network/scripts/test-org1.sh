#!/bin/bash

. set-env.sh

# For test only
for orderer in "${ORDERER_COMPOSE_FILES[@]}"; do
    ./docker-down.sh "${orderer}" --hard
done
for organization in "${ORGANIZATION_COMPOSE_FILES[@]}"; do
    ./docker-down.sh "${organization}" --hard
done

./network-init.sh # As the admin organization only

# Docker setup
for orderer in "${ORDERER_COMPOSE_FILES[@]}"; do
    ./docker-up.sh "${orderer}" # Initialize the container for the orderer
done
./docker-up.sh "${ORGANIZATION_COMPOSE_FILES[0]}" # Initialize the organization 1 container

# Channel setup
./network-join-orderer.sh 1
./network-join-orderer.sh 2
./network-join-organization.sh # Join the organization 1 to the network

sleep 20

# Deploy the chaincode
./chaincode-install.sh # Install the chaincode on all peers
./chaincode-approve.sh # Approve the chaincode for the organization
./chaincode-commit.sh # Commit the chaincode definition to the channel 