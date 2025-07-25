#!/bin/bash

. ../network.config

export FABRIC_VERSION

find ${NETWORK_COMPOSE_PATH} -name "docker-compose*.yaml" -o -name "docker-compose*.yml" | while read -r compose_file; do
    docker compose -f "$compose_file" -p ${DOCKER_PROJECT_NAME} down --volumes --remove-orphans
done
docker volume prune -f
docker network prune -f


# Delete runtime directories

if [ -d ${NETWORK_CHANNEL_PATH} ]; then
    rm -rf ${NETWORK_CHANNEL_PATH}
fi

if [ -d ${NETWORK_PROFILE_PATH} ]; then
    rm -rf ${NETWORK_PROFILE_PATH}
fi