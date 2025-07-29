#!/bin/bash

. set-env.sh

HARD=false
if [[ "$1" == "--hard" ]]; then
    HARD=true
fi

find ${NETWORK_CMP_PATH} -name "docker-compose*.yaml" -o -name "docker-compose*.yml" | while read -r compose_file; do
    if [[ "$HARD" == true ]]; then
        docker compose -f "$compose_file" -p ${DOCKER_PROJECT_NAME} down --volumes --remove-orphans
        rm -rf ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH} ${NETWORK_LOG_PATH}
    else
        docker compose -f "$compose_file" -p ${DOCKER_PROJECT_NAME} down --remove-orphans
    fi
    docker volume prune -f
done