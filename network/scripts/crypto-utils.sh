#!/bin/bash

. set-env.sh

generate_crypto() {

    local CRYPTO_CONFIG_FILE=$1

    if [ ! -d ${NETWORK_ORG_PATH} ]; then
        mkdir -p ${NETWORK_ORG_PATH}/peerOrganizations ${NETWORK_ORG_PATH}/ordererOrganizations
    fi

    cryptogen generate --config=${CRYPTO_CONFIG_FILE} --output=${NETWORK_ORG_PATH}
    echo "Cryptographic material generated successfully in ${NETWORK_ORG_PATH}"
}

generate_definition() {
    local ORG_NAME=$1
    local ORG_DOMAIN=$2
    local CONFIGTX_FILE=$3

    CONFIGTX_DIR=$(dirname ${CONFIGTX_FILE})
    configtxgen -configPath ${CONFIGTX_DIR} -printOrg ${ORG_NAME}MSP > ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json
    echo "Organization definition generated successfully in ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json"
}


