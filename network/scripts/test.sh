#!/bin/bash

. set-env.sh
. ids-utils.sh

./network-init.sh # As the admin organization

./docker-up.sh "${COMPOSE_FILES[0]}" # As the organization that is running the orderer 1
./docker-up.sh "${COMPOSE_FILES[1]}" # As the organization that is running the orderer 2
./docker-up.sh "${COMPOSE_FILES[2]}" # As the organization that is running the peers of org1
./docker-up.sh "${COMPOSE_FILES[3]}" # As the organization that is running the peers of org2
./docker-up.sh "${COMPOSE_FILES[4]}" # As the organization that is running the peers of org3

./network-join-orderer.sh "${COMPOSE_FILES[0]}" # Join the first orderer to the network
./network-join-orderer.sh "${COMPOSE_FILES[1]}" # Join the second orderer to the network

sleep 5 

./docker-down.sh "${COMPOSE_FILES[0]}" --hard
./docker-down.sh "${COMPOSE_FILES[1]}" --hard
./docker-down.sh "${COMPOSE_FILES[2]}" --hard
./docker-down.sh "${COMPOSE_FILES[3]}" --hard
./docker-down.sh "${COMPOSE_FILES[4]}" --hard