#!/bin/bash

. ../network.config

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

export CORE_PEER_TLS_ENABLED=true

# Listen address for orderers and peers
ORDERERS=(
    "localhost:7050"
    "localhost:8050"
)

PEERS=(
    "localhost:7051"
    "localhost:8051"
    "localhost:9051"
    # TODO: This should contain also the endpoints for new organizations
)

# Admin listen address for orderers
ORDERER_ADMIN_ADDRESSES=(
    "localhost:7053"
    "localhost:8053"
)

# Peers and Orderer TLS CA certificates
ORDERER_CA=${NETWORK_ORG_PATH}/ordererOrganizations/ord.testbed.local/tlsca/tlsca.ord.testbed.local-cert.pem
PEERS_CA=(
    ${NETWORK_ORG_PATH}/peerOrganizations/org1.testbed.local/tlsca/tlsca.org1.testbed.local-cert.pem
    ${NETWORK_ORG_PATH}/peerOrganizations/org2.testbed.local/tlsca/tlsca.org2.testbed.local-cert.pem
    ${NETWORK_ORG_PATH}/peerOrganizations/org3.testbed.local/tlsca/tlsca.org3.testbed.local-cert.pem
    # TODO: This should contain also the TLS CA certificates for new organizations
)

set_orderer() {
    local orderer_id=$1 # Input the orderer id

    export ORDERER_ADDR=${ORDERERS[$((orderer_id - 1))]}
    export ORDERER_HOST="orderer${orderer_id}.ord.testbed.local"

    echo "Setting environment for ${ORDERER_HOST} at ${ORDERER_ADDR}"
}

set_admin_orderer() {
    local orderer_id=$1 # Input the orderer id

    export ORDERER_ADMIN_ADDR=${ORDERER_ADMIN_ADDRESSES[$((orderer_id - 1))]}
    export ORDERER_ADMIN_HOST="orderer${orderer_id}.ord.testbed.local"
    export ORDERER_ADMIN_TLS_CA=${NETWORK_ORG_PATH}/ordererOrganizations/ord.testbed.local/tlsca/tlsca.ord.testbed.local-cert.pem
    export ORDERER_ADMIN_TLS_SIGN_CERT=${NETWORK_ORG_PATH}/ordererOrganizations/ord.testbed.local/orderers/${ORDERER_ADMIN_HOST}/tls/server.crt
    export ORDERER_ADMIN_TLS_PRIVATE_KEY=${NETWORK_ORG_PATH}/ordererOrganizations/ord.testbed.local/orderers/${ORDERER_ADMIN_HOST}/tls/server.key

    echo "Setting admin environment for ${ORDERER_ADMIN_HOST} at ${ORDERER_ADMIN_ADDR}"
}

set_organization() {
    local org_id=$1 # Input the organization id
    local org_name="org${org_id}"
    
    export CORE_PEER_LOCALMSPID="$(tr '[:lower:]' '[:upper:]' <<< ${org_name:0:1})${org_name:1}MSP"
    export CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_ORG_PATH}/peerOrganizations/${org_name}.testbed.local/tlsca/tlsca.${org_name}.testbed.local-cert.pem
    export CORE_PEER_MSPCONFIGPATH=${NETWORK_ORG_PATH}/peerOrganizations/${org_name}.testbed.local/users/Admin@${org_name}.testbed.local/msp
    export CORE_PEER_ADDRESS=${PEERS[$((org_id - 1))]}
    export CORE_PEER_TLS_SERVERHOSTOVERRIDE="peer0.${org_name}.testbed.local"
    export CORE_PEER_TLS_ENABLED=true
    export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

    echo "Setting environment for ${CORE_PEER_LOCALMSPID} at ${CORE_PEER_ADDRESS}"
}