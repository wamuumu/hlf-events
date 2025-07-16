#!/bin/bash

. ../network.config
. set-env.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

export COMPOSE_BAKE=true
export FABRIC_VERSION

export ORG_ID=4
export ORG_NAME="Org4"
export ORG_DOMAIN="org4.testbed.local"
export PEER_COUNT=1
export USER_COUNT=1
export PEER_PORT=10051
export CHAINCODE_PORT=10052
export OPERATIONS_PORT=9448

function generate_org_crypto() {
    which cryptogen > /dev/null

    if [ $? -ne 0 ]; then
        echo "cryptogen not found in PATH. Please install Hyperledger Fabric binaries."
        exit 1
    else
        echo "Cryptogen tool found at: $(which cryptogen)"
        
        TEMP_CONFIG=$(mktemp)
        envsubst < ${FABRIC_CFG_PATH}/org-crypto.yaml > ${TEMP_CONFIG}

        cryptogen generate --config=${TEMP_CONFIG} --output=${NETWORK_ORG_PATH}

        rm ${TEMP_CONFIG}
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

        TEMP_CONFIG=$(mktemp)
        envsubst < ${FABRIC_CFG_PATH}/org-configtx.yaml > ${TEMP_CONFIG}

        mv ${FABRIC_CFG_PATH}/configtx.yaml ${FABRIC_CFG_PATH}/configtx.tmp.yaml
        mv ${TEMP_CONFIG} ${FABRIC_CFG_PATH}/configtx.yaml

        configtxgen -printOrg ${ORG_NAME}MSP > ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json

        rm ${FABRIC_CFG_PATH}/configtx.yaml
        mv ${FABRIC_CFG_PATH}/configtx.tmp.yaml ${FABRIC_CFG_PATH}/configtx.yaml

        echo "Organization definition generated successfully in ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json"
    fi
}

function organization_up() {

    export ORG_NAME_LOWER=$(echo "${ORG_NAME}" | tr '[:upper:]' '[:lower:]')

    TEMP_COMPOSE=$(mktemp)
    envsubst < ${NETWORK_COMPOSE_PATH}/docker-organization-compose.yaml > ${TEMP_COMPOSE}

    mv ${TEMP_COMPOSE} ${NETWORK_COMPOSE_PATH}/docker-compose-temp.yaml
    
    # Check if the container exists and stop it if it does
    if docker ps -a -q -f name=peer0.${ORG_DOMAIN} | grep -q .; then
        echo "Stopping existing peer0.${ORG_DOMAIN} container..."
        docker stop peer0.${ORG_DOMAIN} 2>/dev/null || true
        docker rm peer0.${ORG_DOMAIN} 2>/dev/null || true
    fi

    docker compose -f ${NETWORK_COMPOSE_PATH}/docker-compose-temp.yaml -p ${DOCKER_PROJECT_NAME} up -d

    rm ${NETWORK_COMPOSE_PATH}/docker-compose-temp.yaml
}

function create_join_transaction() {

    CHANNEL=${NETWORK_CHANNEL_NAME}
    ORIGINAL=${NETWORK_CHANNEL_PATH}/${NETWORK_CHANNEL_NAME}.json
    MODIFIED=${NETWORK_CHANNEL_PATH}/modified_config.json
    OUTPUT=${NETWORK_CHANNEL_PATH}/update_in_envelope.pb

    # Extract the config part from the block JSON
    CONFIG_JSON=${NETWORK_CHANNEL_PATH}/config_only.json
    jq '.data.data[0].payload.data.config' ${ORIGINAL} > ${CONFIG_JSON}

    # Add the new organization to the config
    jq -s --arg org_name "${ORG_NAME}" '.[0] * {"channel_group":{"groups":{"Application":{"groups": {($org_name + "MSP"):.[1]}}}}}' ${CONFIG_JSON} ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json > ${MODIFIED}
    rm ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json

    configtxlator proto_encode --input "${CONFIG_JSON}" --type common.Config --output ${NETWORK_CHANNEL_PATH}/original_config.pb
    configtxlator proto_encode --input "${MODIFIED}" --type common.Config --output ${NETWORK_CHANNEL_PATH}/modified_config.pb
    configtxlator compute_update --channel_id "${CHANNEL}" --original ${NETWORK_CHANNEL_PATH}/original_config.pb --updated ${NETWORK_CHANNEL_PATH}/modified_config.pb --output ${NETWORK_CHANNEL_PATH}/config_update.pb
    configtxlator proto_decode --input ${NETWORK_CHANNEL_PATH}/config_update.pb --type common.ConfigUpdate --output ${NETWORK_CHANNEL_PATH}/config_update.json
    echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL'", "type":2}},"data":{"config_update":'$(cat ${NETWORK_CHANNEL_PATH}/config_update.json)'}}}' | jq . > ${NETWORK_CHANNEL_PATH}/config_update_in_envelope.json
    configtxlator proto_encode --input ${NETWORK_CHANNEL_PATH}/config_update_in_envelope.json --type common.Envelope --output "${OUTPUT}"

    set_organization 1
    peer channel signconfigtx -f ${OUTPUT}

    set_orderer 1
    set_organization 2
    peer channel update -f ${OUTPUT} -c ${CHANNEL} -o ${ORDERER_ADDR} --ordererTLSHostnameOverride ${ORDERER_HOST} --tls --cafile ${ORDERER_CA}

    # rm all the created files, except for the mychannel.block and mychannel.json
    rm ${NETWORK_CHANNEL_PATH}/original_config.pb
    rm ${NETWORK_CHANNEL_PATH}/modified_config.pb
    rm ${NETWORK_CHANNEL_PATH}/config_update.pb
    rm ${NETWORK_CHANNEL_PATH}/config_update.json
    rm ${NETWORK_CHANNEL_PATH}/config_update_in_envelope.json
    rm ${NETWORK_CHANNEL_PATH}/config_only.json
    rm ${NETWORK_CHANNEL_PATH}/update_in_envelope.pb
    rm ${NETWORK_CHANNEL_PATH}/modified_config.json
}

function join_channel() {
    BLOCKFILE=${NETWORK_CHANNEL_PATH}/${NETWORK_CHANNEL_NAME}.block

    set_organization ${ORG_ID}
    export CORE_PEER_ADDRESS="localhost:10051"

    set_orderer 1
    peer channel join -b $BLOCKFILE
}

if [ ! -d "${NETWORK_ORG_PATH}/ordererOrganizations" ]; then
    echo "Network not initialized. Exiting..."
    exit 1
fi

if [ -d "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}" ]; then
    echo "Organization ${ORG_NAME} certificates already exist. Removing and regenerating..."
    rm -rf "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}"
fi

echo "Generating certificates for organization ${ORG_NAME}..."
generate_org_crypto
generate_org_definition
organization_up
echo "Sleeping for 5 seconds to allow container to start..."
sleep 5

create_join_transaction
join_channel 