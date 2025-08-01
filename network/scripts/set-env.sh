#!/bin/bash

. ../network.config

export PATH=${PATH}:${NETWORK_BIN_PATH}
export FABRIC_CFG_PATH=${NETWORK_CFG_PATH}
export COMPOSE_BAKE=true
export FABRIC_VERSION

# TODO: move files away from this script

# General Files
GENESIS_BLOCK=${NETWORK_CHN_PATH}/genesis.block
CC_PKG_PATH=${NETWORK_PKG_PATH}/${CC_NAME}_${CC_VERSION}.tar.gz
ORD_JSON_FILE=${NETWORK_IDS_PATH}/orderers.json
ORG_JSON_FILE=${NETWORK_IDS_PATH}/organizations.json
PEERS_JSON_FILE=${NETWORK_IDS_PATH}/peers.json

# These are the files describing the initial state of the network in the genesis block
CONFIGTX_FILE=${NETWORK_CFG_PATH}/configtx.yaml
CRYPTO_CONFIG_FILE=${NETWORK_CFG_PATH}/crypto-config.yaml
ORDERER_COMPOSE_FILES=(
    "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml"
    "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml"
)
ORGANIZATION_COMPOSE_FILES=(
    "${NETWORK_CMP_PATH}/docker-compose-org1.yaml"
    "${NETWORK_CMP_PATH}/docker-compose-org2.yaml"
    "${NETWORK_CMP_PATH}/docker-compose-org3.yaml"
)

set_orderer() {
    local orderer=$(jq -r ".\"$1\"" ${ORD_JSON_FILE})

    ORDERER_NAME=$(echo "$orderer" | jq -r '.ordName')
    ORDERER_DOMAIN=$(echo "$orderer" | jq -r '.ordDomain')
    export ORDERER_HOST=$(echo "$orderer" | jq -r '.ordHost')
    export ORDERER_ADDRESS=$(echo "$orderer" | jq -r '.listenAddress')
    export ORDERER_ADMIN_ADDRESS=$(echo "$orderer" | jq -r '.adminListenAddress')
    export ORDERER_TLS_CA="${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/tlsca/tlsca.${ORDERER_DOMAIN}-cert.pem"
    export ORDERER_TLS_SIGN_CERT="${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/orderers/${ORDERER_HOST}/tls/server.crt"
    export ORDERER_TLS_PRIVATE_KEY="${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/orderers/${ORDERER_HOST}/tls/server.key"

    echo "Setting environment for ${ORDERER_NAME} (ID: $1):"
    echo "  Address: ${ORDERER_ADDRESS}"
    echo "  Admin Address: ${ORDERER_ADMIN_ADDRESS}"
    echo "  TLS Host: ${ORDERER_HOST}"
    echo "  TLS CA: ${ORDERER_TLS_CA}"
    echo "  TLS Sign Cert: ${ORDERER_TLS_SIGN_CERT}"
    echo "  TLS Private Key: ${ORDERER_TLS_PRIVATE_KEY}"
}

set_peer() {
    local peer=$(jq -r ".\"$1\"" ${PEERS_JSON_FILE})

    PEER_NAME=$(echo "$peer" | jq -r '.peerName')
    PEER_DOMAIN=$(echo "$peer" | jq -r '.peerDomain')
    export CORE_PEER_TLS_ENABLED=true
    export CORE_PEER_LOCALMSPID=$(echo "$peer" | jq -r '.localMspId')
    export CORE_PEER_ADDRESS=$(echo "$peer" | jq -r '.listenAddress')
    export CORE_PEER_TLS_ROOTCERT_FILE="${NETWORK_ORG_PATH}/peerOrganizations/${PEER_DOMAIN}/tlsca/tlsca.${PEER_DOMAIN}-cert.pem"
    export CORE_PEER_MSPCONFIGPATH="${NETWORK_ORG_PATH}/peerOrganizations/${PEER_DOMAIN}/users/Admin@${PEER_DOMAIN}/msp"

    echo "Setting environment for ${PEER_NAME} (ID: $1):"
    echo "  Address: ${CORE_PEER_ADDRESS}"
    echo "  Local MSP ID: ${CORE_PEER_LOCALMSPID}"
    echo "  TLS Root Cert: ${CORE_PEER_TLS_ROOTCERT_FILE}"
    echo "  MSP Config Path: ${CORE_PEER_MSPCONFIGPATH}"
    echo "  TLS Enabled: ${CORE_PEER_TLS_ENABLED}"
}