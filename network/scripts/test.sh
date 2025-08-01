#!/bin/bash

. set-env.sh
. ids-utils.sh

./network-init.sh # As the admin organization

# Docker setup
for orderer in "${ORDERER_COMPOSE_FILES[@]}"; do
    ./docker-up.sh "${orderer}" # Initialize the container for the orderer
done
for organization in "${ORGANIZATION_COMPOSE_FILES[@]}"; do
    ./docker-up.sh "${organization}" # Initialize the container for each organization
done

# Channel setup
for orderer in "${ORDERER_COMPOSE_FILES[@]}"; do
    ./network-join-orderer.sh "${orderer}" # Join each orderer to the network
done
for organization in "${ORGANIZATION_COMPOSE_FILES[@]}"; do
    ./network-join-organization.sh "${organization}" # Join each organization peer to the network
done

sleep 5 

for orderer in "${ORDERER_COMPOSE_FILES[@]}"; do
    ./docker-down.sh "${orderer}" --hard
done
for organization in "${ORGANIZATION_COMPOSE_FILES[@]}"; do
    ./docker-down.sh "${organization}" --hard
done