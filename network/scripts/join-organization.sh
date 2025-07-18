#!/bin/bash

. ../network.config
. set-env.sh
. update-config.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

export COMPOSE_BAKE=true
export FABRIC_VERSION
export DOCKER_PROJECT_NAME

# Params definition
ORG_ID=$1
CRYPTO_FILE=${FABRIC_CFG_PATH}/$2
CONFIGTX_FILE=${FABRIC_CFG_PATH}/$3
COMPOSE_FILE=${NETWORK_COMPOSE_PATH}/$4

# Variables extraction from configuration files
ORG_NAME=$(yq -r '.PeerOrgs[0].Name' ${CRYPTO_FILE})
ORG_DOMAIN=$(yq -r '.PeerOrgs[0].Domain' ${CRYPTO_FILE})
PEER_ADDRESS=$(yq -r '.services | to_entries | .[0].value.environment[] | select(. | startswith("CORE_PEER_ADDRESS=")) | sub("CORE_PEER_ADDRESS="; "")' ${COMPOSE_FILE})
PEER_HOST=$(echo $PEER_ADDRESS | cut -d: -f1)
PEER_PORT=$(echo $PEER_ADDRESS | cut -d: -f2)

function generate_org_crypto() {
    which cryptogen > /dev/null

    if [ $? -ne 0 ]; then
        echo "cryptogen not found in PATH. Please install Hyperledger Fabric binaries."
        exit 1
    else
        echo "Cryptogen tool found at: $(which cryptogen)"

        cryptogen generate --config=${CRYPTO_FILE} --output=${NETWORK_ORG_PATH}

        echo "Cryptographic material generated successfully in ${NETWORK_ORG_PATH}"
    fi
}

function generate_org_definition() {
    which configtxgen > /dev/null

    if [ $? -ne 0 ]; then
        echo "configtxgen not found in PATH. Please install Hyperledger Fabric binaries."
        exit 1
    else
        echo "Configtxgen tool found at: $(which configtxgen)"

        CONFIGTX_DIR=$(dirname ${CONFIGTX_FILE})
        configtxgen -configPath ${CONFIGTX_DIR} -printOrg ${ORG_NAME}MSP > ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json

        echo "Organization definition generated successfully in ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json"
    fi
}

function organization_up() {
    
    # Check if the container exists and stop it if it does
    if docker ps -a -q -f name=${PEER_HOST} | grep -q .; then
        echo "Stopping existing ${PEER_HOST} container..."
        docker stop ${PEER_HOST} 2>/dev/null || true
        docker rm ${PEER_HOST} 2>/dev/null || true
    fi

    docker compose -f ${COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} up -d --no-recreate
}

function join_channel() {

    echo "Joining organization ${ORG_NAME} to the channel ${NETWORK_CHANNEL_NAME}"

    fetch_channel_config 1
    # Add the new organization to the config
    jq -s --arg org_name "${ORG_NAME}" '.[0] * {"channel_group":{"groups":{"Application":{"groups": {($org_name + "MSP"):.[1]}}}}}' ${ORIGINAL} ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json > ${MODIFIED}
    
    create_update_transaction

    # In order to remove the organization, the admin policies must be satisfied.
    # This requires that "MAJORITY of the organizations" sign the config update transaction.
    # As of now, use the three existing organizations. 
    # TODO: change this
    for i in {1..3}; do
        set_organization $i
        peer channel signconfigtx -f ${OUTPUT}
    done

    # Submit the signed config update transaction to the orderer
    set_orderer 1
    peer channel update \
        -f ${OUTPUT} \
        -c ${NETWORK_CHANNEL_NAME} \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_CA}

    # Remove all the intermediary files, except for the genesis.block
    rm ${NETWORK_CHANNEL_PATH}/*.json
    rm ${NETWORK_CHANNEL_PATH}/*.pb

    set_organization ${ORG_ID}
    export CORE_PEER_ADDRESS="localhost:10051"

    BLOCKFILE=${NETWORK_CHANNEL_PATH}/genesis.block
    peer channel join -b $BLOCKFILE

    echo "Organization ${ORG_NAME} successfully added to channel ${NETWORK_CHANNEL_NAME}"
}

function set_anchor_peer() {

    echo "Setting anchor peer for organization ${ORG_NAME} on channel ${NETWORK_CHANNEL_NAME}"

    # Fetch the current channel configuration to add the anchor peer
    fetch_channel_config ${ORG_ID}
    jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'${PEER_HOST}'","port": '${PEER_PORT}'}]},"version": "0"}}' ${NETWORK_CHANNEL_PATH}/config.json > ${NETWORK_CHANNEL_PATH}/modified_config.json

    # Create the anchor peer update transaction
    create_update_transaction

    peer channel update \
        -f ${OUTPUT} \
        -c ${NETWORK_CHANNEL_NAME} \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_CA}
    
    # Remove all the intermediary files, except for the genesis.block
    rm ${NETWORK_CHANNEL_PATH}/*.json
    rm ${NETWORK_CHANNEL_PATH}/*.pb
}

if [ ! -d "${NETWORK_ORG_PATH}/ordererOrganizations" ]; then
    echo "Network not initialized. Exiting..."
    exit 1
fi

if [ -d "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}" ]; then
    echo "Organization ${ORG_NAME} certificates already exist. Removing and regenerating..."
    rm -rf "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}"
fi

generate_org_crypto
generate_org_definition
organization_up
join_channel
set_anchor_peer

echo "Organization ${ORG_NAME} has been successfully added to the network."
