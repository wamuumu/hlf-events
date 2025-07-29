#!/bin/bash

. ids-utils.sh

export COMPOSE_BAKE=true
export FABRIC_VERSION

COMPOSE_FILE=${NETWORK_CMP_PATH}/docker-compose.yaml
CRYPTO_CONFIG_FILE=${NETWORK_CFG_PATH}/crypto-config.yaml

# Create runtime directories
mkdir -p ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH}

# Create IDs files
init_organizations ${CRYPTO_CONFIG_FILE}
init_orderers ${CRYPTO_CONFIG_FILE}
update_services ${COMPOSE_FILE}

docker compose -f ${COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} up -d