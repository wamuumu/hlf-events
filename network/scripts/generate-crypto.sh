#!/bin/bash

. ../network.config

export PATH=${PATH}:${FABRIC_BIN_PATH}

if [ -d ${NETWORK_ORG_PATH} ]; then
    rm -rf ${NETWORK_ORG_PATH}
fi

mkdir -p ${NETWORK_ORG_PATH}/peerOrganizations ${NETWORK_ORG_PATH}/ordererOrganizations

which cryptogen > /dev/null

if [ $? -ne 0 ]; then
    echo "cryptogen not found in PATH. Please install Hyperledger Fabric binaries."
    exit 1
else
    echo "Cryptogen tool found at: $(which cryptogen)"
    cryptogen generate --config=${FABRIC_CFG_PATH}/crypto-config.yaml --output=${NETWORK_ORG_PATH}
    echo "Cryptographic material generated successfully in ../organizations"
fi


