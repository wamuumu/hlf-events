#!/bin/bash

. set-env.sh

copy_msp_tls_certs() {

    # Copy the MSP and TLS certificates
    # Also initialize the endpoints.json file for the identity

    local crypto_config_file=$1

    local org=$(yq -r '.PeerOrgs' ${crypto_config_file})
    local ord=$(yq -r '.OrdererOrgs' ${crypto_config_file})
    [[ "$org" == "null" ]] && type="ordererOrganizations" || type="peerOrganizations"

    if [[ "$org" == "null" ]]; then
        type="ordererOrganizations"
        data=$(echo "$ord" | jq -r 'to_entries[0] | .value')
    else
        type="peerOrganizations"
        data=$(echo "$org" | jq -r 'to_entries[0] | .value')
    fi

    local name=$(echo "$data" | jq -r '.Name')
    local domain=$(echo "$data" | jq -r ".Domain")

    # Prepare whole directory and files
    ORG_DIR="${NETWORK_IDS_PATH}/${name,,}"
    mkdir -p "${ORG_DIR}/msp/cacerts" "${ORG_DIR}/msp/tlscacerts"
    echo "{}" > "${ORG_DIR}/endpoints.json"

    cp "${NETWORK_ORG_PATH}/${type}/${domain}/ca/ca.${domain}-cert.pem" "${ORG_DIR}/msp/cacerts/ca.${domain}-cert.pem"
    cp "${NETWORK_ORG_PATH}/${type}/${domain}/tlsca/tlsca.${domain}-cert.pem" "${ORG_DIR}/msp/tlscacerts/tlsca.${domain}-cert.pem"

    echo ${ORG_DIR}
}

generate_endpoints() {
    
    local org_dir=$1
    local docker_compose_file=$2

    # Extract the endpoints from the docker compose file
    local services=$(yq -r '.services | to_entries | .[] | @json' ${docker_compose_file})

    while IFS= read -r service; do

        local json_file="${org_dir}/endpoints.json"
        local service_id=$(($(jq 'keys | length' ${json_file}) + 1))
        local service_type=$(echo "$service" | jq -r '.value.image | split(":") | .[0] | split("/") | .[-1] | sub("fabric-"; "")') # This returns peer or orderer
        
        if [[ "$service_type" == "peer" ]]; then
            PEER_HOSTNAME=$(echo "$service" | jq -r '.key')
            PEER_GENERAL_LISTEN_PORT=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_ADDRESS=")) | sub("CORE_PEER_ADDRESS="; "") | split(":") | .[-1]')
            PEER_LISTEN_PORT="${DEFAULT_ENDPOINT}:${PEER_GENERAL_LISTEN_PORT}"
            PEER_LOCAL_MSPID=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_LOCALMSPID=")) | sub("CORE_PEER_LOCALMSPID="; "")')

            jq \
                --arg peerId "$service_id" \
                --arg peerHost "$PEER_HOSTNAME" \
                --arg listenPort "$PEER_LISTEN_PORT" \
                --arg localMspId "$PEER_LOCAL_MSPID" \
                '.[$peerId] = {hostname: $peerHost, address: $listenPort, localMspId: $localMspId}' \
                "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
        
        elif [[ "$service_type" == "orderer" ]]; then
            ORDERER_HOSTNAME=$(echo "$service" | jq -r '.key')
            ORDERER_GENERAL_LISTEN_PORT=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_GENERAL_LISTENPORT=")) | sub("ORDERER_GENERAL_LISTENPORT="; "")')
            ORDERER_LISTEN_ADDRESS="${DEFAULT_ENDPOINT}:${ORDERER_GENERAL_LISTEN_PORT}"
            ORDERER_ADMIN_LISTEN_PORT=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_ADMIN_LISTENADDRESS=")) | sub("ORDERER_ADMIN_LISTENADDRESS="; "") | split(":") | .[-1]')
            ORDERER_ADMIN_LISTEN_ADDRESS="${DEFAULT_ENDPOINT}:${ORDERER_ADMIN_LISTEN_PORT}"

            jq \
                --arg ordId "$service_id" \
                --arg ordHost "$ORDERER_HOSTNAME" \
                --arg listenAddress "$ORDERER_LISTEN_ADDRESS" \
                --arg adminListenAddress "$ORDERER_ADMIN_LISTEN_ADDRESS" \
                '.[$ordId] = {hostname: $ordHost, address: $listenAddress, adminAddress: $adminListenAddress}' \
                "${json_file}" > "${json_file}.tmp" && mv "${json_file}.tmp" "${json_file}"
        fi
    done <<< "$services"
}