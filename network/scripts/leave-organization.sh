#!/bin/bash

. ../network.config
. set-env.sh
. update-config.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

export COMPOSE_BAKE=true
export FABRIC_VERSION
export DOCKER_PROJECT_NAME

ORGANIZATIONS_JSON_FILE=${NETWORK_PROFILE_PATH}/organizations.json

# Params definition
ORG_ID=$1
ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})

# Variables extraction from configuration files
ORG_NAME=$(jq -r ".\"$ORG_ID\".orgName" ${ORGANIZATIONS_JSON_FILE})
ORG_DOMAIN=$(jq -r ".\"$ORG_ID\".orgDomain" ${ORGANIZATIONS_JSON_FILE})

function clear_organization_profile() {
    jq "del(.\"$ORG_ID\")" ${ORGANIZATIONS_JSON_FILE} > ${ORGANIZATIONS_JSON_FILE}.tmp && mv ${ORGANIZATIONS_JSON_FILE}.tmp ${ORGANIZATIONS_JSON_FILE}
    echo "Organization profile for ${ORG_NAME} cleared from ${ORGANIZATIONS_JSON_FILE}"
}

function leave_channel() {

    echo "Removing organization ${ORG_NAME} from the channel ${NETWORK_CHANNEL_NAME}"

    fetch_channel_config 1
    # Remove the organization from the config
    jq --arg org_name "${ORG_NAME}" 'del(.channel_group.groups.Application.groups[($org_name + "MSP")])' ${ORIGINAL} > ${MODIFIED}
    
    create_update_transaction

    # In order to remove the organization, the admin policies must be satisfied.
    # This requires that "MAJORITY of the organizations" sign the config update transaction.
    # Sign with all the peers of all organizations
    
    for ((i=1; i<=${ORG_COUNT}; i++)); do
        PEER_COUNT=$(jq -r ".\"$i\".peers | length" ${ORGANIZATIONS_JSON_FILE})
        for ((j=1; j<=PEER_COUNT; j++)); do
            set_organization_peer $i $j
            peer channel signconfigtx -f ${OUTPUT}
        done
    done

    # Submit the signed config update transaction to the orderer
    set_orderer 1
    peer channel update \
        -f ${OUTPUT} \
        -c ${NETWORK_CHANNEL_NAME} \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_ADMIN_TLS_CA}

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
clear_organization_profile

echo "Organization ${ORG_NAME} has been successfully removed from the network."