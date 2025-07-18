#!/bin/bash

. ../network.config
. set-env.sh

ORIGINAL=${NETWORK_CHANNEL_PATH}/config.json
MODIFIED=${NETWORK_CHANNEL_PATH}/modified_config.json
OUTPUT=${NETWORK_CHANNEL_PATH}/${ORG_NAME,,}_update_in_envelope.pb

function fetch_channel_config() {

    ORG=$1
    OUTPUT=${NETWORK_CHANNEL_PATH}/config.json

    set_orderer 1
    set_organization ${ORG}

    echo "Fetching the most recent configuration block for the channel"
    peer channel fetch config ${NETWORK_CHANNEL_PATH}/config_block.pb \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        -c ${NETWORK_CHANNEL_NAME} \
        --tls \
        --cafile ${ORDERER_CA}

    echo "Decoding config block to JSON and isolating config to ${OUTPUT}"
    configtxlator proto_decode \
        --input ${NETWORK_CHANNEL_PATH}/config_block.pb \
        --type common.Block \
        --output ${NETWORK_CHANNEL_PATH}/config_block.json
    
    jq .data.data[0].payload.data.config ${NETWORK_CHANNEL_PATH}/config_block.json > "${OUTPUT}"
}

function create_update_transaction() {

    # Encode the original configuration in protobuf format
    configtxlator proto_encode \
        --input "${ORIGINAL}" \
        --type common.Config \
        --output ${NETWORK_CHANNEL_PATH}/original_config.pb

    # Encode the modified configuration in protobuf format
    configtxlator proto_encode \
        --input "${MODIFIED}" \
        --type common.Config \
        --output ${NETWORK_CHANNEL_PATH}/modified_config.pb

    # Compute the config update between the original and modified configurations
    configtxlator compute_update \
        --channel_id "${NETWORK_CHANNEL_NAME}" \
        --original ${NETWORK_CHANNEL_PATH}/original_config.pb \
        --updated ${NETWORK_CHANNEL_PATH}/modified_config.pb \
        --output ${NETWORK_CHANNEL_PATH}/config_update.pb

    # Decode the config update to JSON format
    configtxlator proto_decode \
        --input ${NETWORK_CHANNEL_PATH}/config_update.pb \
        --type common.ConfigUpdate \
        --output ${NETWORK_CHANNEL_PATH}/config_update.json

    echo '{"payload":{"header":{"channel_header":{"channel_id":"'${NETWORK_CHANNEL_NAME}'", "type":2}},"data":{"config_update":'$(cat ${NETWORK_CHANNEL_PATH}/config_update.json)'}}}' | jq . > ${NETWORK_CHANNEL_PATH}/config_update_in_envelope.json

    # Encode the config update in envelope format
    configtxlator proto_encode \
        --input ${NETWORK_CHANNEL_PATH}/config_update_in_envelope.json \
        --type common.Envelope \
        --output "${OUTPUT}"
}