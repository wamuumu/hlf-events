#!/bin/bash

. set-env.sh

ORG_COUNT=$(jq -r 'length' ${ORG_JSON_FILE})
ORD_COUNT=$(jq -r 'length' ${ORD_JSON_FILE})

mkdir -p ${NETWORK_LOG_PATH}/join

create_genesis_block() {
    configtxgen \
        -configPath ${NETWORK_CFG_PATH} \
        -profile ChannelUsingRaft \
        -outputBlock ${GENESIS_BLOCK} \
        -channelID ${NETWORK_CHN_NAME} \
        >> ${NETWORK_LOG_PATH}/join/genesis.log 2>&1

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create genesis block. Check ${NETWORK_LOG_PATH}/join/genesis.log for details."
        exit 1
    else
        echo "Genesis block created successfully at ${GENESIS_BLOCK}"
    fi
}

join_orderer_to_channel() {
    set_orderer ${DEFAULT_ORD} >> ${NETWORK_LOG_PATH}/join/orderer.log 2>&1
    osnadmin channel join \
        --channelID ${NETWORK_CHN_NAME} \
        --config-block ${GENESIS_BLOCK} \
        -o ${ORDERER_ADMIN_ADDR} \
        --ca-file ${ORDERER_ADMIN_TLS_CA} \
        --client-cert ${ORDERER_ADMIN_TLS_SIGN_CERT} \
        --client-key ${ORDERER_ADMIN_TLS_PRIVATE_KEY} \
        >> ${NETWORK_LOG_PATH}/join/orderer.log 2>&1

    if [ $? -ne 0 ]; then
        echo "Error: Failed to join orderer ${ORDERER_HOST} to channel '${NETWORK_CHN_NAME}'. Check ${NETWORK_LOG_PATH}/join/orderer.log for details."
        exit 1
    else
        echo "Orderer ${ORDERER_HOST} joined channel '${NETWORK_CHN_NAME}' successfully."
    fi
}

join_peer_to_channel() {
    set_organization_peer $1 $2 >> ${NETWORK_LOG_PATH}/join/peer.log 2>&1
    peer channel join -b ${GENESIS_BLOCK} >> ${NETWORK_LOG_PATH}/join/peer.log 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to join peer ${CORE_PEER_LOCALMSPID} (${CORE_PEER_ADDRESS}) to channel '${NETWORK_CHN_NAME}'. Check ${NETWORK_LOG_PATH}/join/peer.log for details."
        exit 1
    else
        echo "Peer ${CORE_PEER_LOCALMSPID} (${CORE_PEER_ADDRESS}) joined channel '${NETWORK_CHN_NAME}' successfully."
    fi
}

# Create genesis block
create_genesis_block

# Join orderers to the channel
for ((i=1; i<=ORD_COUNT; i++)); do
    join_orderer_to_channel $i
done

# Join peers to the channel
for ((i=1; i<=ORG_COUNT; i++)); do
    PEER_COUNT=$(jq -r ".\"$i\".peers | length" ${ORG_JSON_FILE})
    for ((j=1; j<=PEER_COUNT; j++)); do
        join_peer_to_channel $i $j
    done
done