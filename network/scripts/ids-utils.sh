#!/bin/bash

. set-env.sh

generate_identities() {
    local CONFIGTX_FILE=$1
    local CRYPTO_CONFIG_FILE=$2

    # Create the JSON files containing the identities
    echo "{}" > ${ORG_JSON_FILE}
    echo "{}" > ${ORD_JSON_FILE}

    # Initialize organizations and orderers
    init_organizations ${CRYPTO_CONFIG_FILE}
    init_orderers ${CRYPTO_CONFIG_FILE}

    # Fill the identities with the information from the compose files
    fill_identities "${COMPOSE_FILES[@]}"
}

init_organizations() {
    local CRYPTO_CONFIG_FILE=$1
    PEER_ORGANIZATIONS=$(yq -r '.PeerOrgs' ${CRYPTO_CONFIG_FILE})
    for ORG in $(echo "${PEER_ORGANIZATIONS}" | jq -r 'keys[]'); do
        ORG_NAME=$(echo "${PEER_ORGANIZATIONS}" | jq -r ".[$ORG].Name")
        ORG_DOMAIN=$(echo "${PEER_ORGANIZATIONS}" | jq -r ".[$ORG].Domain")
        ORG_MSPID=$ORG_NAME"MSP"

        ORG_ID=$(($(jq 'keys | length' ${ORG_JSON_FILE}) + 1))
        jq \
            --arg orgId "$ORG_ID" \
            --arg orgName "$ORG_NAME" \
            --arg orgDomain "$ORG_DOMAIN" \
            --arg orgMspId "$ORG_MSPID" \
            '.[$orgId] = {orgName: $orgName, orgDomain: $orgDomain, orgMspId: $orgMspId, peers: []}' \
            "${ORG_JSON_FILE}" > "${ORG_JSON_FILE}.tmp" && mv "${ORG_JSON_FILE}.tmp" "${ORG_JSON_FILE}"

    done
}

init_orderers() {
    local CRYPTO_CONFIG_FILE=$1
    ORDERER_DOMAIN=$(yq -r '.OrdererOrgs[0].Domain' ${CRYPTO_CONFIG_FILE})
    ORDERER_SPECS=$(yq -r '.OrdererOrgs[0].Specs' ${CRYPTO_CONFIG_FILE})
    for ORDERER in $(echo "${ORDERER_SPECS}" | jq -r 'keys[]'); do
        ORDERER_NAME=$(echo "${ORDERER_SPECS}" | jq -r ".[$ORDERER].Hostname")
        
        ORD_ID=$(($(jq 'keys | length' ${ORD_JSON_FILE}) + 1))
        jq \
            --arg ordId "$ORD_ID" \
            --arg ordName "$ORDERER_NAME" \
            --arg ordDomain "$ORDERER_DOMAIN" \
            '.[$ordId] = {ordName: $ordName, ordDomain: $ordDomain}' \
            "${ORD_JSON_FILE}" > "${ORD_JSON_FILE}.tmp" && mv "${ORD_JSON_FILE}.tmp" "${ORD_JSON_FILE}"
    done
}

fill_identities() {
    local COMPOSE_FILES=("$@")
    for COMPOSE_FILE in "${COMPOSE_FILES[@]}"; do
        update_services "${COMPOSE_FILE}"
    done
}

update_services() {
    local COMPOSE_FILE=$1

    # Get the services from the compose file
    SERVICES=$(yq -r '.services | to_entries | .[] | @json' ${COMPOSE_FILE})
    
    # Loop through each service and update the existing identity
    while IFS= read -r service; do
        SERVICE_TYPE=$(echo "$service" | jq -r '.value.image | split(":") | .[0] | split("/") | .[-1] | split("-") | .[1]')
    
        if [[ "$SERVICE_TYPE" == "peer" ]]; then
            PEER_ORG_DOMAIN=$(echo "$service" | jq -r '.key | split(".") | .[1:] | join(".")')
            CORE_PEER_ADDRESS=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_ADDRESS=")) | sub("CORE_PEER_ADDRESS="; "")')
            CORE_PEER_LISTEN_ADDRESS=$(echo "localhost:${CORE_PEER_ADDRESS##*:}")
            CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_ORG_PATH}/peerOrganizations/${PEER_ORG_DOMAIN}/tlsca/tlsca.${PEER_ORG_DOMAIN}-cert.pem
            CORE_PEER_MSPCONFIGPATH=${NETWORK_ORG_PATH}/peerOrganizations/${PEER_ORG_DOMAIN}/users/Admin@${PEER_ORG_DOMAIN}/msp
            
            # Find the organization ID that matches the peer's domain
            ORG_KEY=$(jq -r "to_entries[] | select(.value.orgDomain == \"$PEER_ORG_DOMAIN\") | .key" ${ORG_JSON_FILE})
            
            if [[ -n "$ORG_KEY" ]]; then
                jq \
                    --arg orgKey "$ORG_KEY" \
                    --arg listenAddress "$CORE_PEER_LISTEN_ADDRESS" \
                    --arg corePeerAddress "$CORE_PEER_ADDRESS" \
                    --arg tlsCert "$CORE_PEER_TLS_ROOTCERT_FILE" \
                    --arg mspConfigPath "$CORE_PEER_MSPCONFIGPATH" \
                    '.[$orgKey].peers += [{listenAddress: $listenAddress, corePeerAddress: $corePeerAddress, tlsCert: $tlsCert, mspConfigPath: $mspConfigPath}]' \
                    ${ORG_JSON_FILE} > ${ORG_JSON_FILE}.tmp && mv ${ORG_JSON_FILE}.tmp ${ORG_JSON_FILE}
            else
                echo "Warning: No organization found for domain $PEER_ORG_DOMAIN"
            fi
        elif [[ "$SERVICE_TYPE" == "orderer" ]]; then
            ORDERER_TLS_HOST=$(echo "$service" | jq -r '.key')
            ORDERER_NAME=$(echo "$ORDERER_TLS_HOST" | cut -d'.' -f1)
            ORDERER_DOMAIN=$(echo "$service" | jq -r '.key | split(".") | .[1:] | join(".")')
            ORDERER_LISTENPORT=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_GENERAL_LISTENPORT=")) | sub("ORDERER_GENERAL_LISTENPORT="; "")')
            ORDERER_ADDRESS="localhost:${ORDERER_LISTENPORT}"
            ORDERER_ADMIN_LISTENADDRESS=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_ADMIN_LISTENADDRESS=")) | sub("ORDERER_ADMIN_LISTENADDRESS="; "")')
            ORDERER_ADMIN_ADDR="localhost:${ORDERER_ADMIN_LISTENADDRESS##*:}"
            ORDERER_TLS_CA=${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/tlsca/tlsca.${ORDERER_DOMAIN}-cert.pem
            ORDERER_TLS_SIGN_CERT=${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/orderers/${ORDERER_TLS_HOST}/tls/server.crt
            ORDERER_TLS_PRIVATE_KEY=${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/orderers/${ORDERER_TLS_HOST}/tls/server.key

            # Find the orderer ID that matches the orderer's name
            ORD_KEY=$(jq -r "to_entries[] | select(.value.ordName == \"$ORDERER_NAME\") | .key" ${ORD_JSON_FILE})
            
            if [[ -n "$ORD_KEY" ]]; then
                jq \
                    --arg ordKey "$ORD_KEY" \
                    --arg ordHost "$ORDERER_TLS_HOST" \
                    --arg listenAddress "$ORDERER_ADDRESS" \
                    --arg adminListenAddress "$ORDERER_ADMIN_ADDR" \
                    --arg tlsCa "$ORDERER_TLS_CA" \
                    --arg tlsSignCert "$ORDERER_TLS_SIGN_CERT" \
                    --arg tlsPrivateKey "$ORDERER_TLS_PRIVATE_KEY" \
                    '.[$ordKey] += {ordHost: $ordHost, listenAddress: $listenAddress, adminListenAddress: $adminListenAddress, tlsCa: $tlsCa, tlsSignCert: $tlsSignCert, tlsPrivateKey: $tlsPrivateKey}' \
                    ${ORD_JSON_FILE} > ${ORD_JSON_FILE}.tmp && mv ${ORD_JSON_FILE}.tmp ${ORD_JSON_FILE}
            else
                echo "Warning: No orderer found for name $ORDERER_NAME"
            fi
        else
            echo "Unknown service type: $SERVICE_TYPE"
        fi
    done <<< "$SERVICES"
}

add_organization() {
    local ORG_ID=$1
    local ORG_NAME=$2
    local ORG_DOMAIN=$3
    local COMPOSE_FILE=$4

    jq \
        --arg orgId "$ORG_ID" \
        --arg orgName "$ORG_NAME" \
        --arg orgDomain "$ORG_DOMAIN" \
        '.[$orgId] = {orgName: $orgName, orgDomain: $orgDomain, peers: []}' \
        ${ORG_JSON_FILE} > ${ORG_JSON_FILE}.tmp && mv ${ORG_JSON_FILE}.tmp ${ORG_JSON_FILE}

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
            ${ORG_JSON_FILE} > ${ORG_JSON_FILE}.tmp && mv ${ORG_JSON_FILE}.tmp ${ORG_JSON_FILE}
    done <<< "$SERVICES"
}

generate_orderer() {
    local ORDERER_COMPOSE_FILE=$1
    local SERVICES=$(yq -r '.services | to_entries | .[0] | @json' ${ORDERER_COMPOSE_FILE})

    # Extract orderer information from the compose file
    ORDERER_TLS_HOST=$(echo "$SERVICES" | jq -r '.key')
    ORDERER_NAME=$(echo "$ORDERER_TLS_HOST" | cut -d'.' -f1)
    ORDERER_DOMAIN=$(echo "$SERVICES" | jq -r '.key | split(".") | .[1:] | join(".")')
    ORDERER_LISTENPORT=$(echo "$SERVICES" | jq -r '.value.environment[] | select(. | startswith("ORDERER_GENERAL_LISTENPORT=")) | sub("ORDERER_GENERAL_LISTENPORT="; "")')
    ORDERER_ADDRESS="localhost:${ORDERER_LISTENPORT}"
    ORDERER_ADMIN_LISTENADDRESS=$(echo "$SERVICES" | jq -r '.value.environment[] | select(. | startswith("ORDERER_ADMIN_LISTENADDRESS=")) | sub("ORDERER_ADMIN_LISTENADDRESS="; "")')
    ORDERER_ADMIN_ADDR="localhost:${ORDERER_ADMIN_LISTENADDRESS##*:}"
    ORDERER_TLS_CA=${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/tlsca/tlsca.${ORDERER_DOMAIN}-cert.pem
    ORDERER_TLS_SIGN_CERT=${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/orderers/${ORDERER_TLS_HOST}/tls/server.crt
    ORDERER_TLS_PRIVATE_KEY=${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/orderers/${ORDERER_TLS_HOST}/tls/server.key

    # Create the orderer file
    ORDERER_FILE="${NETWORK_IDS_PATH}/${ORDERER_NAME}.json"
    
    # Populate the file with information from the compose file
    echo '{}' | jq \
        --arg ordHost "$ORDERER_TLS_HOST" \
        --arg listenAddress "$ORDERER_ADDRESS" \
        --arg adminListenAddress "$ORDERER_ADMIN_ADDR" \
        --arg tlsCa "$ORDERER_TLS_CA" \
        --arg tlsSignCert "$ORDERER_TLS_SIGN_CERT" \
        --arg tlsPrivateKey "$ORDERER_TLS_PRIVATE_KEY" \
        '{ordHost: $ordHost, listenAddress: $listenAddress, adminListenAddress: $adminListenAddress, tlsCa: $tlsCa, tlsSignCert: $tlsSignCert, tlsPrivateKey: $tlsPrivateKey}' \
        > ${ORDERER_FILE}
}