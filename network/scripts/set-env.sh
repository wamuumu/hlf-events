#!/bin/bash

. ../network.config

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

ORDERERS_JSON_FILE=${NETWORK_PROFILE_PATH}/orderers.json
ORGANIZATIONS_JSON_FILE=${NETWORK_PROFILE_PATH}/organizations.json

set_orderer() {
    local orderer=$(jq -r ".\"$1\"" ${ORDERERS_JSON_FILE})

    export ORDERER_ADDR=$(echo "$orderer" | jq -r '.address')
    export ORDERER_ADMIN_ADDR=$(echo "$orderer" | jq -r '.adminListenAddress')
    export ORDERER_HOST=$(echo "$orderer" | jq -r '.ordHost')
    export ORDERER_ADMIN_TLS_CA=$(echo "$orderer" | jq -r '.tlsCa')
    export ORDERER_ADMIN_TLS_SIGN_CERT=$(echo "$orderer" | jq -r '.tlsSignCert')
    export ORDERER_ADMIN_TLS_PRIVATE_KEY=$(echo "$orderer" | jq -r '.tlsPrivateKey')

    echo "Setting environment for ${ORDERER_HOST}:"
    echo "  Address: ${ORDERER_ADDR}"
    echo "  Admin Address: ${ORDERER_ADMIN_ADDR}"
    echo "  TLS CA: ${ORDERER_ADMIN_TLS_CA}"
    echo "  TLS Sign Cert: ${ORDERER_ADMIN_TLS_SIGN_CERT}"
    echo "  TLS Private Key: ${ORDERER_ADMIN_TLS_PRIVATE_KEY}"
}

set_organization_peer() {
    local organization=$(jq -r ".\"$1\"" ${ORGANIZATIONS_JSON_FILE})
    local peer=$(echo "$organization" | jq -r ".peers[$2 - 1]")

    # Check if peer exists or is null
    if [[ -z "$peer" || "$peer" == "null" ]]; then
        echo "Error: Peer index $2 does not exist for organization $1. Setting it to the first peer (anchor) by default..."
        peer=$(echo "$organization" | jq -r ".peers[0]")
    fi

    # Set the peer environment variables
    export CORE_PEER_LOCALMSPID=$(echo "$peer" | jq -r '.localMspId')
    export CORE_PEER_TLS_ROOTCERT_FILE=$(echo "$peer" | jq -r '.tlsRootCertFile')
    export CORE_PEER_MSPCONFIGPATH=$(echo "$peer" | jq -r '.mspConfigPath')
    export CORE_PEER_ADDRESS=$(echo "$peer" | jq -r '.address')
    export CORE_PEER_TLS_ENABLED=$(echo "$peer" | jq -r '.tlsEnabled')

    echo "Setting environment for ${CORE_PEER_LOCALMSPID}:"
    echo "  Address: ${CORE_PEER_ADDRESS}"
    echo "  Local MSP ID: ${CORE_PEER_LOCALMSPID}"
    echo "  TLS Root Cert: ${CORE_PEER_TLS_ROOTCERT_FILE}"
    echo "  MSP Config Path: ${CORE_PEER_MSPCONFIGPATH}"
    echo "  TLS Enabled: ${CORE_PEER_TLS_ENABLED}"
}