#!/bin/bash

. set-env.sh

generate_genesis() {
    configtxgen \
        -configPath ${NETWORK_CFG_PATH} \
        -profile ChannelUsingRaft \
        -outputBlock ${GENESIS_BLOCK} \
        -channelID ${NETWORK_CHN_NAME}

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create genesis block. Check ${NETWORK_LOG_PATH}/join/genesis.log for details."
        exit 1
    else
        echo "Genesis block created successfully at ${GENESIS_BLOCK}"
    fi
}

join_orderer() {
    local ord_id=$1

    local endpoints_file="${NETWORK_IDS_PATH}/ords/endpoints.json"
    if [ ! -f "${endpoints_file}" ]; then
        echo "Error: Endpoints file ${endpoints_file} does not exist."
        exit 1
    fi

    set_orderer ${endpoints_file} ${ord_id}
    osnadmin channel join \
        --channelID ${NETWORK_CHN_NAME} \
        --config-block ${GENESIS_BLOCK} \
        -o ${ORDERER_ADMIN_ADDRESS} \
        --ca-file ${ORDERER_TLS_CA} \
        --client-cert ${ORDERER_TLS_SIGN_CERT} \
        --client-key ${ORDERER_TLS_PRIVATE_KEY}
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to join orderer ${ORDERER_HOSTNAME} to channel '${NETWORK_CHN_NAME}'."
        exit 1
    else
        echo "Orderer ${ORDERER_HOSTNAME} joined channel '${NETWORK_CHN_NAME}' successfully."
    fi
}

join_organization() {
    local peers_count=$(jq -r ".\"${DEFAULT_ORG}\".peers | length" ${ORG_JSON_FILE})
    for ((i=1; i<=peers_count; i++)); do
        set_peer ${i}
        peer channel join -b ${GENESIS_BLOCK}

        if [ $? -ne 0 ]; then
            echo "Error: Failed to join peer ${CORE_PEER_ADDRESS} to channel '${NETWORK_CHN_NAME}'."
            exit 1
        else
            echo "Peer ${CORE_PEER_ADDRESS} joined channel '${NETWORK_CHN_NAME}' successfully."
        fi
    done
}

fetch_anchor_peers() {

    # Fetch the latest channel configuration block
    peer channel fetch config ${NETWORK_CHN_PATH}/config_block.pb \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        -c ${NETWORK_CHN_NAME} \
        --tls --cafile ${ORDERER_TLS_CA}
    
    # Convert Proto to JSON
    configtxlator proto_decode \
        --input ${NETWORK_CHN_PATH}/config_block.pb \
        --type common.Block \
        --output ${NETWORK_CHN_PATH}/config_block.json

    jq .data.data[0].payload.data.config ${NETWORK_CHN_PATH}/config_block.json > ${NETWORK_CHN_PATH}/config.json

    # Extract the anchor peers for the organization
    jq '.channel_group.groups.Application.groups 
        | to_entries 
        | map({ org: .key, anchor_peers: .value.values["AnchorPeers"].value.anchor_peers }) 
        | map(select(.anchor_peers != null)) 
        | map({ org: .org, anchor_peer: .anchor_peers[0] })' ${NETWORK_CHN_PATH}/config.json
    
    rm ${NETWORK_CHN_PATH}/*.json
    rm ${NETWORK_CHN_PATH}/*.pb
}

# join_organization() {
#     echo "Joining organization ${ORG_NAME} to the channel ${NETWORK_CHN_NAME}"

#     fetch_channel_config 1
#     # Add the new organization to the config
#     jq -s --arg org_name "${ORG_NAME}" '.[0] * {"channel_group":{"groups":{"Application":{"groups": {($org_name + "MSP"):.[1]}}}}}' ${ORIGINAL} ${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN}/${ORG_NAME,,}.json > ${MODIFIED}
    
#     create_update_transaction

#     # In order to add the organization, the admin policies must be satisfied.
#     # This requires that "MAJORITY of the organizations" sign the config update transaction.
#     # Sign with all the peers of all organizations
    
#     for ((i=1; i<=${ORG_COUNT}; i++)); do
#         PEER_COUNT=$(jq -r ".\"$i\".peers | length" ${ORGANIZATIONS_JSON_FILE})
#         for ((j=1; j<=PEER_COUNT; j++)); do
#             set_organization_peer $i $j
#             peer channel signconfigtx -f ${OUTPUT}
#         done
#     done

#     # Submit the signed config update transaction to the orderer
#     set_orderer 1
#     peer channel update \
#         -f ${OUTPUT} \
#         -c ${NETWORK_CHN_NAME} \
#         -o ${ORDERER_ADDR} \
#         --ordererTLSHostnameOverride ${ORDERER_HOST} \
#         --tls \
#         --cafile ${ORDERER_ADMIN_TLS_CA}

#     # Remove all the intermediary files, except for the genesis.block
#     rm ${NETWORK_CHN_PATH}/*.json
#     rm ${NETWORK_CHN_PATH}/*.pb

#     BLOCKFILE=${NETWORK_CHN_PATH}/genesis.block
#     PEER_COUNT=$(jq -r ".\"$ORG_ID\".peers | length" ${ORGANIZATIONS_JSON_FILE})
#     for ((i=1; i<=PEER_COUNT; i++)); do
#         set_organization_peer ${ORG_ID} $i
#         peer channel join -b $BLOCKFILE
#     done
#     echo "All peers of organization ${ORG_NAME} successfully joined the channel ${NETWORK_CHN_NAME}"

#     echo "Organization ${ORG_NAME} successfully added to channel ${NETWORK_CHN_NAME}"
# }

# set_anchor_peer() {
#     echo "Setting anchor peer for organization ${ORG_NAME} on channel ${NETWORK_CHN_NAME}"

#     # Fetch the current channel configuration to add the anchor peer
#     fetch_channel_config ${ORG_ID}

#     # Set the first peer as the anchor peer
#     ANCHOR_PEER=$(jq -r ".\"$ORG_ID\".peers[0].listenAddress" ${ORGANIZATIONS_JSON_FILE})
#     PEER_HOST=$(echo $ANCHOR_PEER | cut -d: -f1)
#     PEER_PORT=$(echo $ANCHOR_PEER | cut -d: -f2)
#     jq '.channel_group.groups.Application.groups.'${CORE_PEER_LOCALMSPID}'.values += {"AnchorPeers":{"mod_policy": "Admins","value":{"anchor_peers": [{"host": "'${PEER_HOST}'","port": '${PEER_PORT}'}]},"version": "0"}}' ${NETWORK_CHN_PATH}/config.json > ${NETWORK_CHN_PATH}/modified_config.json

#     # Create the anchor peer update transaction
#     create_update_transaction

#     peer channel update \
#         -f ${OUTPUT} \
#         -c ${NETWORK_CHN_NAME} \
#         -o ${ORDERER_ADDR} \
#         --ordererTLSHostnameOverride ${ORDERER_HOST} \
#         --tls \
#         --cafile ${ORDERER_ADMIN_TLS_CA}
    
#     # Remove all the intermediary files, except for the genesis.block
#     rm ${NETWORK_CHN_PATH}/*.json
#     rm ${NETWORK_CHN_PATH}/*.pb
# }