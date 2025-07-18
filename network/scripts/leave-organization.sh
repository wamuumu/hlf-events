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

# Variables extraction from configuration files
ORG_NAME=$(yq -r '.PeerOrgs[0].Name' ${CRYPTO_FILE})
ORG_DOMAIN=$(yq -r '.PeerOrgs[0].Domain' ${CRYPTO_FILE})

function leave_channel() {

    echo "Removing organization ${ORG_NAME} from the channel ${NETWORK_CHANNEL_NAME}"

    fetch_channel_config 1
    # Remove the organization from the config
    jq --arg org_name "${ORG_NAME}" 'del(.channel_group.groups.Application.groups[($org_name + "MSP")])' ${ORIGINAL} > ${MODIFIED}
    
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

    # Remove all the intermediary files
    rm ${NETWORK_CHANNEL_PATH}/*.json
    rm ${NETWORK_CHANNEL_PATH}/*.pb

    echo "Organization ${ORG_NAME} successfully removed from channel ${NETWORK_CHANNEL_NAME}"
}

function organization_down() {
    
    echo "Stopping organization ${ORG_NAME} containers..."

    ORG_CONTAINERS=$(docker ps -a --filter "name=${ORG_DOMAIN}" --format "{{.Names}}" | grep -v "^$" || true)
    if [ ! -z "$ORG_CONTAINERS" ]; then
        echo "Stopping containers for organization ${ORG_DOMAIN}..."
        docker stop $ORG_CONTAINERS 2>/dev/null || true
        docker rm $ORG_CONTAINERS 2>/dev/null || true
    fi
    
    ORG_VOLUMES=$(docker volume ls -q | grep -i ${ORG_NAME,,} || true)
    if [ ! -z "$ORG_VOLUMES" ]; then
        echo "Removing organization-specific volumes..."
        docker volume rm $ORG_VOLUMES 2>/dev/null || true
    fi
}

function cleanup_org_crypto() {
    
    echo "Cleaning up cryptographic material for organization ${ORG_NAME}"
    
    if [ -d "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}" ]; then
        echo "Removing organization certificates and keys..."
        rm -rf "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}"
        echo "Cryptographic material for ${ORG_NAME} removed successfully"
    else
        echo "No cryptographic material found for organization ${ORG_NAME}"
    fi
}

if [ ! -d "${NETWORK_ORG_PATH}/ordererOrganizations" ]; then
    echo "Network not initialized. Exiting..."
    exit 1
fi

if [ ! -d "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}" ]; then
    echo "Organization ${ORG_NAME} does not exist in the network. Nothing to remove."
    exit 1
fi


leave_channel
organization_down
cleanup_org_crypto

echo "Organization ${ORG_NAME} has been successfully removed from the network."