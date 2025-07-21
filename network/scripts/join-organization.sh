#!/bin/bash

. ../network.config
. set-env.sh
. update-config.sh
. cc-utils.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

export COMPOSE_BAKE=true
export FABRIC_VERSION
export DOCKER_PROJECT_NAME

ORGANIZATIONS_JSON_FILE=${NETWORK_PROFILE_PATH}/organizations.json

# Params definition
ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})
ORG_ID=$(($ORG_COUNT + 1))
CRYPTO_FILE=${FABRIC_CFG_PATH}/$1
CONFIGTX_FILE=${FABRIC_CFG_PATH}/$2
COMPOSE_FILE=${NETWORK_COMPOSE_PATH}/$3

# Variables extraction from configuration files
ORG_NAME=$(yq -r '.PeerOrgs[0].Name' ${CRYPTO_FILE})
ORG_DOMAIN=$(yq -r '.PeerOrgs[0].Domain' ${CRYPTO_FILE})

function add_organization_to_profiles() {
    jq \
        --arg orgId "$ORG_ID" \
        --arg orgName "$ORG_NAME" \
        --arg orgDomain "$ORG_DOMAIN" \
        '.[$orgId] = {orgName: $orgName, orgDomain: $orgDomain, peers: []}' \
        ${ORGANIZATIONS_JSON_FILE} > ${ORGANIZATIONS_JSON_FILE}.tmp && mv ${ORGANIZATIONS_JSON_FILE}.tmp ${ORGANIZATIONS_JSON_FILE}

    SERVICES=$(yq -r '.services | to_entries | .[] | @json' ${COMPOSE_FILE})
    while IFS= read -r service; do
        CORE_LISTEN_ADDRESS=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_ADDRESS=")) | sub("CORE_PEER_ADDRESS="; "")')
        CORE_PEER_ADDRESS=$(echo "localhost:${CORE_LISTEN_ADDRESS##*:}")
        CORE_PEER_LOCALMSPID=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_LOCALMSPID=")) | sub("CORE_PEER_LOCALMSPID="; "")')
        CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/tlsca/tlsca.${ORG_DOMAIN}-cert.pem
        CORE_PEER_MSPCONFIGPATH=${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/users/Admin@${ORG_DOMAIN}/msp
        CORE_PEER_TLS_SERVERHOSTOVERRIDE=$(echo "$service" | jq -r '.key')
        CORE_PEER_TLS_ENABLED=true

        jq \
            --arg orgKey "$ORG_ID" \
            --arg listenAddress "$CORE_LISTEN_ADDRESS" \
            --arg address "$CORE_PEER_ADDRESS" \
            --arg localMspId "$CORE_PEER_LOCALMSPID" \
            --arg tlsRootCertFile "$CORE_PEER_TLS_ROOTCERT_FILE" \
            --arg mspConfigPath "$CORE_PEER_MSPCONFIGPATH" \
            --arg tlsServerHostOverride "$CORE_PEER_TLS_SERVERHOSTOVERRIDE" \
            --arg tlsEnabled "$CORE_PEER_TLS_ENABLED" \
            '.[$orgKey].peers += [{listenAddress: $listenAddress, address: $address, localMspId: $localMspId, tlsRootCertFile: $tlsRootCertFile, mspConfigPath: $mspConfigPath, tlsServerHostOverride: $tlsServerHostOverride, tlsEnabled: ($tlsEnabled | test("true"))}]' \
            ${ORGANIZATIONS_JSON_FILE} > ${ORGANIZATIONS_JSON_FILE}.tmp && mv ${ORGANIZATIONS_JSON_FILE}.tmp ${ORGANIZATIONS_JSON_FILE}
    done <<< "$SERVICES"
}

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
    echo "Starting organization ${ORG_NAME} services..."
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

    # Remove all the intermediary files, except for the genesis.block
    rm ${NETWORK_CHANNEL_PATH}/*.json
    rm ${NETWORK_CHANNEL_PATH}/*.pb

    BLOCKFILE=${NETWORK_CHANNEL_PATH}/genesis.block
    PEER_COUNT=$(jq -r ".\"$ORG_ID\".peers | length" ${ORGANIZATIONS_JSON_FILE})
    for ((i=1; i<=PEER_COUNT; i++)); do
        set_organization_peer ${ORG_ID} $i
        peer channel join -b $BLOCKFILE
    done
    echo "All peers of organization ${ORG_NAME} successfully joined the channel ${NETWORK_CHANNEL_NAME}"

    echo "Organization ${ORG_NAME} successfully added to channel ${NETWORK_CHANNEL_NAME}"
}

function set_anchor_peer() {

    echo "Setting anchor peer for organization ${ORG_NAME} on channel ${NETWORK_CHANNEL_NAME}"

    # Fetch the current channel configuration to add the anchor peer
    fetch_channel_config ${ORG_ID}

    # Set the first peer as the anchor peer
    ANCHOR_PEER=$(jq -r ".\"$ORG_ID\".peers[0].listenAddress" ${ORGANIZATIONS_JSON_FILE})
    PEER_HOST=$(echo $ANCHOR_PEER | cut -d: -f1)
    PEER_PORT=$(echo $ANCHOR_PEER | cut -d: -f2)
    jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'${PEER_HOST}'","port": '${PEER_PORT}'}]},"version": "0"}}' ${NETWORK_CHANNEL_PATH}/config.json > ${NETWORK_CHANNEL_PATH}/modified_config.json

    # Create the anchor peer update transaction
    create_update_transaction

    peer channel update \
        -f ${OUTPUT} \
        -c ${NETWORK_CHANNEL_NAME} \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_ADMIN_TLS_CA}
    
    # Remove all the intermediary files, except for the genesis.block
    rm ${NETWORK_CHANNEL_PATH}/*.json
    rm ${NETWORK_CHANNEL_PATH}/*.pb
}

function deploy_chaincode() {
    echo "Deploying chaincode ${CC_NAME} on organization ${ORG_NAME}"

    # Install chaincode on all new peers
    PEER_COUNT=$(jq -r ".\"$ORG_ID\".peers | length" ${ORGANIZATIONS_JSON_FILE})
    for ((i=1; i<=PEER_COUNT; i++)); do
        peer_install_chaincode $ORG_ID $i
    done
    echo "Chaincode installed successfully on all new peers."

    resolveSequence

    # Set the orderer for approvals and commits
    set_orderer 1 

    approve_chaincode
    echo "Chaincode approved for all organizations."

    # Check commit readiness for all the organizations
    check_commit_readiness

    # Commit chaincode definition
    commit_chaincode
    echo "Chaincode committed successfully on all peers."
}

if [ ! -d "${NETWORK_ORG_PATH}/ordererOrganizations" ]; then
    echo "Network not initialized. Exiting..."
    exit 1
fi

if [ -d "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}" ]; then
    echo "Organization ${ORG_NAME} certificates already exist. Removing and regenerating..."
    rm -rf "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}"
fi

add_organization_to_profiles
generate_org_crypto
generate_org_definition
organization_up
join_channel
set_anchor_peer
deploy_chaincode

echo "Organization ${ORG_NAME} has been successfully added to the network."
