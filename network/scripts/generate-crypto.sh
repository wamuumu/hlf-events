#!/bin/bash

. ../network.config

export PATH=${PATH}:${NETWORK_BIN_PATH}

if [ -d ${NETWORK_ORG_PATH} ]; then
    rm -rf ${NETWORK_ORG_PATH}
fi
mkdir -p ${NETWORK_ORG_PATH}/peerOrganizations ${NETWORK_ORG_PATH}/ordererOrganizations

echo "Cryptogen tool found at: $(which cryptogen)"
cryptogen generate --config=${NETWORK_CFG_PATH}/crypto-config.yaml --output=${NETWORK_ORG_PATH}
echo "Cryptographic material generated successfully in ${NETWORK_ORG_PATH}"


