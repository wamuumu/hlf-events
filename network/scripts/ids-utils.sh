#!/bin/bash

. set-env.sh

# TODO: move this two to env variables
ORDERER_ENDPOINT="localhost"
PEER_ENDPOINT="localhost"

generate_orderers() {
    
    # Intialize the orderer JSON file
    echo "{}" > ${ORD_JSON_FILE}

    # Loop through each orderer compose file and extract the necessary information
    local orderer_compose_files=("$@")
    for orderer_compose_file in "${orderer_compose_files[@]}"; do
        local service=$(yq -r '.services | to_entries | .[0] | @json' ${orderer_compose_file})

        # TODO: properly map in dns hostnames
        ORDERER_TLS_HOST=$(echo "$service" | jq -r '.key')
        ORDERER_NAME=$(echo "$ORDERER_TLS_HOST" | cut -d'.' -f1)
        ORDERER_DOMAIN=$(echo "$service" | jq -r '.key | split(".") | .[1:] | join(".")')
        ORDERER_LISTENPORT=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_GENERAL_LISTENPORT=")) | sub("ORDERER_GENERAL_LISTENPORT="; "")')
        ORDERER_LISTEN_ADDRESS="${ORDERER_ENDPOINT}:${ORDERER_LISTENPORT}"
        ORDERER_ADMIN_ADDRESS=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_ADMIN_LISTENADDRESS=")) | sub("ORDERER_ADMIN_LISTENADDRESS="; "")')
        ORDERER_ADMIN_LISTEN_ADDRESS="${ORDERER_ENDPOINT}:${ORDERER_ADMIN_ADDRESS##*:}"

        ORDERER_ID=$(($(jq 'keys | length' ${ORD_JSON_FILE}) + 1))

        jq \
            --arg ordId "$ORDERER_ID" \
            --arg ordName "$ORDERER_NAME" \
            --arg ordDomain "$ORDERER_DOMAIN" \
            --arg ordHost "$ORDERER_TLS_HOST" \
            --arg listenAddress "$ORDERER_LISTEN_ADDRESS" \
            --arg adminListenAddress "$ORDERER_ADMIN_LISTEN_ADDRESS" \
            '.[$ordId] = {ordName: $ordName, ordDomain: $ordDomain, ordHost: $ordHost, listenAddress: $listenAddress, adminListenAddress: $adminListenAddress}' \
            ${ORD_JSON_FILE} > ${ORD_JSON_FILE}.tmp && mv ${ORD_JSON_FILE}.tmp ${ORD_JSON_FILE}
    done
}

extract_orderer_id() {
    local orderer_compose_file=$1
    local service=$(yq -r '.services | to_entries | .[0] | @json' ${orderer_compose_file})
    ORDERER_TLS_HOST=$(echo "$service" | jq -r '.key')

    local ord_id=$(jq -r --arg ordHost "$ORDERER_TLS_HOST" 'to_entries[] | select(.value.ordHost == $ordHost) | .key' ${ORD_JSON_FILE})

    if [ -z "$ord_id" ]; then
        echo "Error: Orderer with host '$ORDERER_TLS_HOST' not found in ${ORD_JSON_FILE}."
        exit 1
    fi

    echo "$ord_id"
}

generate_organizations() {
    
    # Initialize the organization JSON file
    echo "{}" > ${ORG_JSON_FILE}

    # Loop through each organization compose file and extract the necessary information
    local crypto_config_file=$1
    local organizations=$(yq -r '.PeerOrgs' ${crypto_config_file})
    for organization in $(echo "${organizations}" | jq -r 'keys[]'); do
        ORG_NAME=$(echo "${organizations}" | jq -r ".[$organization].Name")
        ORG_DOMAIN=$(echo "${organizations}" | jq -r ".[$organization].Domain")
        # TODO: maybe add more fields like MSPID, GENERAL ENDPOINT, etc... from env variables

        ORG_ID=$(($(jq 'keys | length' ${ORG_JSON_FILE}) + 1))
        jq \
            --arg orgId "$ORG_ID" \
            --arg orgName "$ORG_NAME" \
            --arg orgDomain "$ORG_DOMAIN" \
            '.[$orgId] = {orgName: $orgName, orgDomain: $orgDomain, peers: {}}' \
            "${ORG_JSON_FILE}" > "${ORG_JSON_FILE}.tmp" && mv "${ORG_JSON_FILE}.tmp" "${ORG_JSON_FILE}"
    done
}

extract_organization_id() {
    local organization_compose_file=$1
    local org_domain=$(yq -r '.services | to_entries | .[0] | .key | split(".") | .[1:] | join(".")' ${organization_compose_file})
    local org_id=$(jq -r --arg orgDomain "$org_domain" 'to_entries[] | select(.value.orgDomain == $orgDomain) | .key' ${ORG_JSON_FILE})

    if [ -z "$org_id" ]; then
        echo "Error: Organization with domain '$org_domain' not found in ${ORG_JSON_FILE}."
        exit 1
    fi

    echo "$org_id"
}

generate_peers() {
    local organization_compose_files=("$@")

    for organization_compose_file in "${organization_compose_files[@]}"; do 
        local services=$(yq -r '.services | to_entries | .[] | @json' ${organization_compose_file})
        while IFS= read -r service; do
            PEER_NAME=$(echo "$service" | jq -r '.key | split(".") | .[0]')
            PEER_DOMAIN=$(echo "$service" | jq -r '.key | split(".") | .[1:] | join(".")')
            CORE_PEER_ADDRESS=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_ADDRESS=")) | sub("CORE_PEER_ADDRESS="; "")')
            CORE_PEER_LISTEN_ADDRESS=$(echo "${PEER_ENDPOINT}:${CORE_PEER_ADDRESS##*:}")
            CORE_PEER_LOCALMSPID=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_LOCALMSPID=")) | sub("CORE_PEER_LOCALMSPID="; "")')
            
            ORG_ID=$(jq -r "to_entries[] | select(.value.orgDomain == \"$PEER_DOMAIN\") | .key" ${ORG_JSON_FILE})
            PEER_ID=$(( $(jq -r --arg orgId "$ORG_ID" '.[$orgId].peers | length' ${ORG_JSON_FILE}) + 1 ))

            jq \
                --arg orgId "$ORG_ID" \
                --arg peerId "$PEER_ID" \
                --arg peerName "$PEER_NAME" \
                --arg localMspId "$CORE_PEER_LOCALMSPID" \
                --arg peerDomain "$PEER_DOMAIN" \
                --arg corePeerAddress "$CORE_PEER_ADDRESS" \
                --arg listenAddress "$CORE_PEER_LISTEN_ADDRESS" \
                '.[$orgId].peers[$peerId] = {peerName: $peerName, localMspId: $localMspId, peerDomain: $peerDomain, address: $corePeerAddress, listenAddress: $listenAddress}' \
                ${ORG_JSON_FILE} > ${ORG_JSON_FILE}.tmp && mv ${ORG_JSON_FILE}.tmp ${ORG_JSON_FILE}
        done <<< "$services"
    done
}