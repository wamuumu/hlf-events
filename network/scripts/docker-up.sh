#!/bin/bash

. ../network.config

export COMPOSE_BAKE=true
export FABRIC_VERSION

docker compose -f ${NETWORK_COMPOSE_PATH}/docker-compose.yaml -p ${DOCKER_PROJECT_NAME} up -d