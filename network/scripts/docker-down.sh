#!/bin/bash

. ../network.config

export FABRIC_VERSION

find ${NETWORK_CMP_PATH} -name "docker-compose*.yaml" -o -name "docker-compose*.yml" | while read -r compose_file; do
    docker compose -f "$compose_file" -p ${DOCKER_PROJECT_NAME} down --remove-orphans
done

for arg in "$@"; do
    if [ "$arg" == "--hard" ]; then
        docker volume prune -f
        break
    fi
done