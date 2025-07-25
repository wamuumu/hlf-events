#!/bin/bash

. ../network.config

export PATH=${PATH}:${FABRIC_BIN_PATH}

set_orderer() {
    local orderer=$(jq -r ".\"$1\"" ${ORDERERS_JSON_FILE})

    export ORDERER_ADDR=$(echo "$orderer" | jq -r '.listenAddress')
    export ORDERER_ADMIN_ADDR=$(echo "$orderer" | jq -r '.adminListenAddress')
    export ORDERER_HOST=$(echo "$orderer" | jq -r '.ordHost')
    export ORDERER_ADMIN_TLS_CA=$(echo "$orderer" | jq -r '.tlsCa')
    export ORDERER_ADMIN_TLS_SIGN_CERT=$(echo "$orderer" | jq -r '.tlsSignCert')
    export ORDERER_ADMIN_TLS_PRIVATE_KEY=$(echo "$orderer" | jq -r '.tlsPrivateKey')

    export ORDERER_NAME=$(echo "$orderer" | jq -r '.ordName')
    export SINGULARITYENV_ORDERER_ADDR=$(echo "$orderer" | jq -r '.listenAddress')
    export SINGULARITYENV_ORDERER_ADMIN_ADDR=$(echo "$orderer" | jq -r '.adminListenAddress')
    export SINGULARITYENV_ORDERER_HOST=$(echo "$orderer" | jq -r '.ordHost')
    export SINGULARITYENV_ORDERER_ADMIN_TLS_CA=$(echo "$orderer" | jq -r '.tlsCa')
    export SINGULARITYENV_ORDERER_ADMIN_TLS_SIGN_CERT=$(echo "$orderer" | jq -r '.tlsSignCert')
    export SINGULARITYENV_ORDERER_ADMIN_TLS_PRIVATE_KEY=$(echo "$orderer" | jq -r '.tlsPrivateKey')

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

    export PEER_NAME=$(echo "$peer" | jq -r '.peerName')
    export CORE_PEER_LOCALMSPID=$(echo "$peer" | jq -r '.localMspId')
    export CORE_PEER_TLS_ROOTCERT_FILE=$(echo "$peer" | jq -r '.tlsRootCertFile')
    export CORE_PEER_MSPCONFIGPATH=$(echo "$peer" | jq -r '.mspConfigPath')
    export CORE_PEER_ADDRESS=$(echo "$peer" | jq -r '.listenAddress')
    export CORE_PEER_TLS_ENABLED=true
    export FABRIC_CFG_PATH

    export SINGULARITYENV_CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID
    export SINGULARITYENV_CORE_PEER_TLS_ROOTCERT_FILE="/etc/hyperledger/fabric/tlsca/cert.pem"
    export SINGULARITYENV_CORE_PEER_MSPCONFIGPATH="/etc/hyperledger/fabric/admin/msp"
    export SINGULARITYENV_CORE_PEER_ADDRESS=$(echo "$peer" | jq -r '.listenAddress')
    export SINGULARITYENV_CORE_PEER_TLS_ENABLED=true
    export SINGULARITYENV_FABRIC_CFG_PATH="/etc/hyperledger/fabric"

    echo "Setting environment for ${CORE_PEER_LOCALMSPID}:"
    echo "  Address: ${CORE_PEER_ADDRESS}"
    echo "  Local MSP ID: ${CORE_PEER_LOCALMSPID}"
    echo "  TLS Root Cert: ${CORE_PEER_TLS_ROOTCERT_FILE}"
    echo "  MSP Config Path: ${CORE_PEER_MSPCONFIGPATH}"
    echo "  TLS Enabled: ${CORE_PEER_TLS_ENABLED}"
}