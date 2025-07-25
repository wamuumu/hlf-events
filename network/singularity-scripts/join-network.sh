#!/bin/bash

. set-env.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}

# Files
BLOCKFILE=${NETWORK_CHANNEL_PATH}/genesis.block

# Variables
ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})
ORD_COUNT=$(jq -r 'length' ${ORDERERS_JSON_FILE})

create_genesis_block() {
    which configtxgen > /dev/null
    if [ $? -ne 0 ]; then
        echo "Cryptogen not found in PATH. Please install Hyperledger Fabric binaries."
        exit 1
    else
        configtxgen -configPath ${FABRIC_CFG_PATH} -profile ChannelUsingRaft -outputBlock ${BLOCKFILE} -channelID ${NETWORK_CHANNEL_NAME}
        echo "Channel genesis block created successfully at ${BLOCKFILE}"
    fi
}

join_orderer_to_channel() {
    which osnadmin > /dev/null
    if [ $? -ne 0 ]; then
        echo "osnadmin tool not found in PATH. Please install Hyperledger Fabric binaries."
        exit 1
    else
        set_orderer $1 # Orderer ID
        echo "Joining ${ORDERER_HOST} (${ORDERER_ADMIN_ADDR}) to channel '${NETWORK_CHANNEL_NAME}'..."
        osnadmin channel join \
            --channelID ${NETWORK_CHANNEL_NAME} \
            --config-block ${BLOCKFILE} \
            -o ${ORDERER_ADMIN_ADDR} \
            --ca-file ${ORDERER_ADMIN_TLS_CA} \
            --client-cert ${ORDERER_ADMIN_TLS_SIGN_CERT} \
            --client-key ${ORDERER_ADMIN_TLS_PRIVATE_KEY} >> ${LOGS}/${ORDERER_NAME}.log
        echo "Orderer ${ORDERER_HOST} joined channel '${NETWORK_CHANNEL_NAME}' successfully."
    fi
}

join_peer_to_channel() {
    set_organization_peer $1 $2
    echo "Joining ${PEER_NAME} to channel '${NETWORK_CHANNEL_NAME}'..."
    export SINGULARITYENV_BLOCKFILE="/etc/hyperledger/fabric/channel/genesis.block"
    singularity exec instance://${PEER_NAME} peer channel join -b ${BLOCKFILE}
    echo "Peer ${PEER_NAME} joined channel '${NETWORK_CHANNEL_NAME}' successfully."
}

# Create genesis block
create_genesis_block

# Join orderers to the channel
for ((i=1; i<=ORD_COUNT; i++)); do
    join_orderer_to_channel $i
done


# Join peers to the channel
for ((i=1; i<=ORG_COUNT; i++)); do
    PEER_COUNT=$(jq -r ".\"$i\".peers | length" ${ORGANIZATIONS_JSON_FILE})
    for ((j=1; j<=PEER_COUNT; j++)); do
        join_peer_to_channel $i $j
    done
done