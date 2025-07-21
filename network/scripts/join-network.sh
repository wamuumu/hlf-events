#!/bin/bash

. ../network.config
. set-env.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}

ORGANIZATIONS_JSON_FILE=${NETWORK_PROFILE_PATH}/organizations.json
ORDERERS_JSON_FILE=${NETWORK_PROFILE_PATH}/orderers.json

BLOCKFILE=${NETWORK_CHANNEL_PATH}/genesis.block
ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})
ORD_COUNT=$(jq -r 'length' ${ORDERERS_JSON_FILE})

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
    set_orderer $1 # Orderer ID

    echo "Joining ${ORDERER_HOST} (${ORDERER_ADMIN_ADDR}) to channel '${NETWORK_CHANNEL_NAME}'..."
    osnadmin channel join \
        --channelID ${NETWORK_CHANNEL_NAME} \
        --config-block ${BLOCKFILE} \
        -o ${ORDERER_ADMIN_ADDR} \
        --ca-file ${ORDERER_ADMIN_TLS_CA} \
        --client-cert ${ORDERER_ADMIN_TLS_SIGN_CERT} \
        --client-key ${ORDERER_ADMIN_TLS_PRIVATE_KEY}
}

join_peer_to_channel() {
    set_organization_peer $1 $2 # Organization ID and Peer index

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
    for ((i=1; i<=ORD_COUNT; i++)); do
        join_orderer_to_channel $i
    done
    echo "Orderers joined to channel '${NETWORK_CHANNEL_NAME}' successfully."
fi

# Join peers to the channel
which peer > /dev/null
if [ $? -ne 0 ]; then
    echo "peer CLI tool not found in PATH. Please install Hyperledger Fabric binaries."
    exit 1
else
    echo "Peer CLI tool found at: $(which peer)"
    for ((i=1; i<=ORG_COUNT; i++)); do
        PEER_COUNT=$(jq -r ".\"$i\".peers | length" ${ORGANIZATIONS_JSON_FILE})
        for ((j=1; j<=PEER_COUNT; j++)); do
            join_peer_to_channel $i $j
        done
    done
    echo "Peers joined to channel '${NETWORK_CHANNEL_NAME}' successfully."
fi