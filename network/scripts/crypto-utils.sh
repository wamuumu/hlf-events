#!/bin/bash

. set-env.sh

generate_crypto() {

    local CRYPTO_CONFIG_FILE=$1

    cryptogen generate --config=${CRYPTO_CONFIG_FILE} --output=${NETWORK_ORG_PATH} > /dev/null 2>&1
    echo "Cryptographic material generated successfully in ${NETWORK_ORG_PATH}"
}

delete_crypto() {

    local ORG_DOMAIN=$1

    rm -rf "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN,,}"
    echo "Cryptographic material for organization ${ORG_DOMAIN} deleted successfully."
}


