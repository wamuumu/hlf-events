#!/bin/bash

. ../network.config

export FABRIC_VERSION

docker compose -f ${NETWORK_COMPOSE_PATH}/docker-compose.yaml -p ${DOCKER_PROJECT_NAME} down --volumes --remove-orphans
docker volume prune -f
docker network prune -f

REMAINING_CONTAINERS=$(docker ps -aq --filter "name=${DOCKER_PROJECT_NAME}" 2>/dev/null)
if [ ! -z "${REMAINING_CONTAINERS}" ]; then
    docker rm -f ${REMAINING_CONTAINERS}
fi