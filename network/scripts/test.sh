#!/bin/bash

. set-env.sh
. ids-utils.sh

./network-init.sh # As the admin organization

./docker-up.sh "${COMPOSE_FILES[0]}" # As the organization that is running the orderer 1
./docker-up.sh "${COMPOSE_FILES[1]}" # As the organization that is running the orderer 2
./docker-up.sh "${COMPOSE_FILES[2]}" # As the organization that is running the peers of org1
./docker-up.sh "${COMPOSE_FILES[3]}" # As the organization that is running the peers of org2
./docker-up.sh "${COMPOSE_FILES[4]}" # As the organization that is running the peers of org3

./network-join-orderer.sh "${COMPOSE_FILES[0]}" "${NETWORK_IDS_PATH}/orderer1.json" # Join the first orderer to the network

./docker-down.sh "${COMPOSE_FILES[0]}" --hard
./docker-down.sh "${COMPOSE_FILES[1]}" --hard
./docker-down.sh "${COMPOSE_FILES[2]}" --hard
./docker-down.sh "${COMPOSE_FILES[3]}" --hard
./docker-down.sh "${COMPOSE_FILES[4]}" --hard