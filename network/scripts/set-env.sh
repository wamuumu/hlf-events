#!/bin/bash

. ../network.config

export PATH=${PATH}:${NETWORK_BIN_PATH}
export FABRIC_CFG_PATH=${NETWORK_CFG_PATH}
export COMPOSE_BAKE=true
export FABRIC_VERSION

# General Files
GENESIS_BLOCK=${NETWORK_CHN_PATH}/genesis.block
CC_PKG_PATH=${NETWORK_PKG_PATH}/${CC_NAME}_${CC_VERSION}.tar.gz
ORD_JSON_FILE=${NETWORK_IDS_PATH}/orderers.json
ORG_JSON_FILE=${NETWORK_IDS_PATH}/organizations.json

# These are the files describing the initial state of the network in the genesis block
CONFIGTX_FILE=${NETWORK_CFG_PATH}/configtx.yaml
CRYPTO_CONFIG_FILE=${NETWORK_CFG_PATH}/crypto-config.yaml
COMPOSE_FILES=(
    "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml"
    "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml"
    "${NETWORK_CMP_PATH}/docker-compose-org1.yaml"
    "${NETWORK_CMP_PATH}/docker-compose-org2.yaml"
    "${NETWORK_CMP_PATH}/docker-compose-org3.yaml"
)

set_orderer() {
    local orderer=$(jq -r ".\"$1\"" ${ORD_JSON_FILE})

    export ORDERER_ADDRESS=$(echo "$orderer" | jq -r '.listenAddress')
    export ORDERER_ADMIN_ADDRESS=$(echo "$orderer" | jq -r '.adminListenAddress')
    export ORDERER_HOST=$(echo "$orderer" | jq -r '.ordHost')
    export ORDERER_TLS_CA=$(echo "$orderer" | jq -r '.tlsCa')
    export ORDERER_TLS_SIGN_CERT=$(echo "$orderer" | jq -r '.tlsSignCert')
    export ORDERER_TLS_PRIVATE_KEY=$(echo "$orderer" | jq -r '.tlsPrivateKey')

    echo "Setting environment for ${ORDERER_HOST}:"
    echo "  Address: ${ORDERER_ADDRESS}"
    echo "  Admin Address: ${ORDERER_ADMIN_ADDRESS}"
    echo "  TLS CA: ${ORDERER_TLS_CA}"
    echo "  TLS Sign Cert: ${ORDERER_TLS_SIGN_CERT}"
    echo "  TLS Private Key: ${ORDERER_TLS_PRIVATE_KEY}"
}

set_orderer_from_file() {
    local orderer_file=$1
    
    # Read the entire JSON file content
    local orderer=$(cat "${orderer_file}")

    export ORDERER_ADDRESS=$(echo "$orderer" | jq -r '.listenAddress')
    export ORDERER_ADMIN_ADDRESS=$(echo "$orderer" | jq -r '.adminListenAddress')
    export ORDERER_HOST=$(echo "$orderer" | jq -r '.ordHost')
    export ORDERER_TLS_CA=$(echo "$orderer" | jq -r '.tlsCa')
    export ORDERER_TLS_SIGN_CERT=$(echo "$orderer" | jq -r '.tlsSignCert')
    export ORDERER_TLS_PRIVATE_KEY=$(echo "$orderer" | jq -r '.tlsPrivateKey')

    echo "Setting environment for orderer from file:"
    echo "  Address: ${ORDERER_ADDRESS}"
    echo "  Admin Address: ${ORDERER_ADMIN_ADDRESS}"
    echo "  TLS CA: ${ORDERER_TLS_CA}"
    echo "  TLS Sign Cert: ${ORDERER_TLS_SIGN_CERT}"
    echo "  TLS Private Key: ${ORDERER_TLS_PRIVATE_KEY}"
}

set_organization_peer() {
    local organization=$(jq -r ".\"$1\"" ${ORG_JSON_FILE})
    local peer=$(echo "$organization" | jq -r ".peers[$2 - 1]")

    # Set the peer environment variables
    export CORE_PEER_ADDRESS=$(echo "$peer" | jq -r '.listenAddress')
    export CORE_PEER_TLS_ROOTCERT_FILE=$(echo "$peer" | jq -r '.tlsCert')
    export CORE_PEER_MSPCONFIGPATH=$(echo "$peer" | jq -r '.mspConfigPath')
    export CORE_PEER_LOCALMSPID=$(echo "$organization" | jq -r '.orgMspId')
    export CORE_PEER_TLS_ENABLED=true

    echo "Setting environment for ${CORE_PEER_LOCALMSPID}:"
    echo "  Address: ${CORE_PEER_ADDRESS}"
    echo "  Local MSP ID: ${CORE_PEER_LOCALMSPID}"
    echo "  TLS Root Cert: ${CORE_PEER_TLS_ROOTCERT_FILE}"
    echo "  MSP Config Path: ${CORE_PEER_MSPCONFIGPATH}"
    echo "  TLS Enabled: ${CORE_PEER_TLS_ENABLED}"
}