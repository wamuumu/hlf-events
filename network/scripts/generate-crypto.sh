#!/bin/bash

. set-env.sh

if [ -d ${NETWORK_ORG_PATH} ]; then
    rm -rf ${NETWORK_ORG_PATH}
fi
mkdir -p ${NETWORK_ORG_PATH}/peerOrganizations ${NETWORK_ORG_PATH}/ordererOrganizations

cryptogen generate --config=${NETWORK_CFG_PATH}/crypto-config.yaml --output=${NETWORK_ORG_PATH}
echo "Cryptographic material generated successfully in ${NETWORK_ORG_PATH}"


