#!/bin/bash

. ../network.config
. set-env.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}

BLOCKFILE=${NETWORK_CHANNEL_PATH}/genesis.block

if [ -d ${NETWORK_CHANNEL_PATH} ]; then
    rm -rf ${NETWORK_CHANNEL_PATH}
fi

mkdir -p ${NETWORK_CHANNEL_PATH}

# Create channel genesis block
which configtxgen > /dev/null

if [ $? -ne 0 ]; then
    echo "cryptogen not found in PATH. Please install Hyperledger Fabric binaries."
    exit 1
else
    echo "Configtxgen tool found at: $(which configtxgen)"
    configtxgen -configPath ${FABRIC_CFG_PATH} -profile ChannelUsingRaft -outputBlock ${BLOCKFILE} -channelID ${NETWORK_CHANNEL_NAME}
    echo "Channel genesis block created successfully at ${BLOCKFILE}"
fi

join_orderer_to_channel() {
    local orderer_id=$1
    set_admin_orderer "$orderer_id"

    echo "Joining ${ORDERER_ADMIN_HOST} (${ORDERER_ADMIN_ADDR}) to channel '${NETWORK_CHANNEL_NAME}'..."
    osnadmin channel join \
        --channelID ${NETWORK_CHANNEL_NAME} \
        --config-block ${BLOCKFILE} \
        -o ${ORDERER_ADMIN_ADDR} \
        --ca-file ${ORDERER_ADMIN_TLS_CA} \
        --client-cert ${ORDERER_ADMIN_TLS_SIGN_CERT} \
        --client-key ${ORDERER_ADMIN_TLS_PRIVATE_KEY}
}

join_peer_to_channel() {
    local org_id=$1
    set_organization "$org_id"

    echo "Joining ${CORE_PEER_ADDRESS} to channel '${NETWORK_CHANNEL_NAME}'..."
    
    if peer channel join -b ${BLOCKFILE} 2>&1; then
        echo "Peer successfully joined the channel."
    else
        echo "Channel join command returned an error. Checking if peer is already in the channel..."
        
        # Check if the peer is already part of the channel
        if peer channel list | grep -q "${NETWORK_CHANNEL_NAME}"; then
            echo "Peer is already a member of channel '${NETWORK_CHANNEL_NAME}'. This is expected if running the script multiple times."
        else
            echo "Peer is not in the channel and the join operation failed. This needs investigation."
            return 1
        fi
    fi
}

# Join orderers to the channel
which osnadmin > /dev/null
if [ $? -ne 0 ]; then
    echo "osnadmin tool not found in PATH. Please install Hyperledger Fabric binaries."
    exit 1
else
    echo "Osnadmin tool found at: $(which osnadmin)"
    join_orderer_to_channel 1
    join_orderer_to_channel 2
    echo "Orderers joined to channel '${NETWORK_CHANNEL_NAME}' successfully."
fi

# Join peers to the channel
which peer > /dev/null
if [ $? -ne 0 ]; then
    echo "peer CLI tool not found in PATH. Please install Hyperledger Fabric binaries."
    exit 1
else
    echo "Peer CLI tool found at: $(which peer)"
    join_peer_to_channel 1
    join_peer_to_channel 2
    join_peer_to_channel 3
    echo "Peers joined to channel '${NETWORK_CHANNEL_NAME}' successfully."
fi