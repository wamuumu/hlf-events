#!/bin/bash

. ../network.config
. set-env.sh

init_organizations() {
    local CRYPTO_CONFIG_FILE=$1
    echo "{}" > ${ORG_JSON_FILE}
    PEER_ORGANIZATIONS=$(yq -r '.PeerOrgs' ${CRYPTO_CONFIG_FILE})
    for ORG in $(echo "${PEER_ORGANIZATIONS}" | jq -r 'keys[]'); do
        ORG_NAME=$(echo "${PEER_ORGANIZATIONS}" | jq -r ".[$ORG].Name")
        ORG_DOMAIN=$(echo "${PEER_ORGANIZATIONS}" | jq -r ".[$ORG].Domain")
        
        ORG_ID=$(($(jq 'keys | length' ${ORG_JSON_FILE}) + 1))
        jq \
            --arg orgId "$ORG_ID" \
            --arg orgName "$ORG_NAME" \
            --arg orgDomain "$ORG_DOMAIN" \
            '.[$orgId] = {orgName: $orgName, orgDomain: $orgDomain, peers: []}' \
            "${ORG_JSON_FILE}" > "${ORG_JSON_FILE}.tmp" && mv "${ORG_JSON_FILE}.tmp" "${ORG_JSON_FILE}"

    done
}

init_orderers() {
    local CRYPTO_CONFIG_FILE=$1
    echo "{}" > ${ORD_JSON_FILE}
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

update_services() {
    local COMPOSE_FILE=$1
    SERVICES=$(yq -r '.services | to_entries | .[] | @json' ${COMPOSE_FILE})
    while IFS= read -r service; do
        SERVICE_TYPE=$(echo "$service" | jq -r '.value.image | split(":") | .[0] | split("/") | .[-1] | split("-") | .[1]')
    
        if [[ "$SERVICE_TYPE" == "peer" ]]; then
            PEER_ORG_DOMAIN=$(echo "$service" | jq -r '.key | split(".") | .[1:] | join(".")')
            CORE_LISTEN_ADDRESS=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_ADDRESS=")) | sub("CORE_PEER_ADDRESS="; "")')
            CORE_PEER_ADDRESS=$(echo "localhost:${CORE_LISTEN_ADDRESS##*:}")
            CORE_PEER_LOCALMSPID=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_LOCALMSPID=")) | sub("CORE_PEER_LOCALMSPID="; "")')
            CORE_PEER_TLS_ROOTCERT_FILE=${NETWORK_ORG_PATH}/peerOrganizations/${PEER_ORG_DOMAIN}/tlsca/tlsca.${PEER_ORG_DOMAIN}-cert.pem
            CORE_PEER_MSPCONFIGPATH=${NETWORK_ORG_PATH}/peerOrganizations/${PEER_ORG_DOMAIN}/users/Admin@${PEER_ORG_DOMAIN}/msp
            CORE_PEER_TLS_ENABLED=true
            
            # Find the organization ID that matches the peer's domain
            ORG_KEY=$(jq -r "to_entries[] | select(.value.orgDomain == \"$PEER_ORG_DOMAIN\") | .key" ${ORG_JSON_FILE})
            
            if [[ -n "$ORG_KEY" ]]; then
                # Add peer to the existing organization's peers array
                jq \
                --arg orgKey "$ORG_KEY" \
                --arg listenAddress "$CORE_LISTEN_ADDRESS" \
                --arg address "$CORE_PEER_ADDRESS" \
                --arg localMspId "$CORE_PEER_LOCALMSPID" \
                --arg tlsRootCertFile "$CORE_PEER_TLS_ROOTCERT_FILE" \
                --arg mspConfigPath "$CORE_PEER_MSPCONFIGPATH" \
                --arg tlsEnabled "$CORE_PEER_TLS_ENABLED" \
                '.[$orgKey].peers += [{listenAddress: $listenAddress, address: $address, localMspId: $localMspId, tlsRootCertFile: $tlsRootCertFile, mspConfigPath: $mspConfigPath, tlsEnabled: ($tlsEnabled | test("true"))}]' \
                ${ORG_JSON_FILE} > ${ORG_JSON_FILE}.tmp && mv ${ORG_JSON_FILE}.tmp ${ORG_JSON_FILE}
            else
                echo "Warning: No organization found for domain $PEER_ORG_DOMAIN"
            fi
        elif [[ "$SERVICE_TYPE" == "orderer" ]]; then
            ORDERER_TLS_HOST=$(echo "$service" | jq -r '.key')
            ORDERER_NAME=$(echo "$ORDERER_TLS_HOST" | cut -d'.' -f1)
            ORDERER_DOMAIN=$(echo "$service" | jq -r '.key | split(".") | .[1:] | join(".")')
            ORDERER_LISTENADDRESS=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_GENERAL_LISTENADDRESS=")) | sub("ORDERER_GENERAL_LISTENADDRESS="; "")')
            ORDERER_LISTENPORT=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_GENERAL_LISTENPORT=")) | sub("ORDERER_GENERAL_LISTENPORT="; "")')
            ORDERER_ADDRESS="localhost:${ORDERER_LISTENPORT}"
            ORDERER_LOCALMSPID=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_GENERAL_LOCALMSPID=")) | sub("ORDERER_GENERAL_LOCALMSPID="; "")')
            ORDERER_ADMIN_LISTENADDRESS=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("ORDERER_ADMIN_LISTENADDRESS=")) | sub("ORDERER_ADMIN_LISTENADDRESS="; "")')
            ORDERER_ADMIN_ADDR="localhost:${ORDERER_ADMIN_LISTENADDRESS##*:}"
            ORDERER_TLS_CA=${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/tlsca/tlsca.${ORDERER_DOMAIN}-cert.pem
            ORDERER_TLS_SIGN_CERT=${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/orderers/${ORDERER_TLS_HOST}/tls/server.crt
            ORDERER_TLS_PRIVATE_KEY=${NETWORK_ORG_PATH}/ordererOrganizations/${ORDERER_DOMAIN}/orderers/${ORDERER_TLS_HOST}/tls/server.key

            # Find the orderer ID that matches the orderer's name
            ORD_KEY=$(jq -r "to_entries[] | select(.value.ordName == \"$ORDERER_NAME\") | .key" ${ORD_JSON_FILE})
            
            if [[ -n "$ORD_KEY" ]]; then
                # Add orderer details to the existing orderer entry
                jq \
                --arg ordKey "$ORD_KEY" \
                --arg ordHost "$ORDERER_TLS_HOST" \
                --arg listenAddress "$ORDERER_LISTENADDRESS" \
                --arg port "$ORDERER_LISTENPORT" \
                --arg address "$ORDERER_ADDRESS" \
                --arg localMspId "$ORDERER_LOCALMSPID" \
                --arg adminListenAddress "$ORDERER_ADMIN_ADDR" \
                --arg tlsCa "$ORDERER_TLS_CA" \
                --arg tlsSignCert "$ORDERER_TLS_SIGN_CERT" \
                --arg tlsPrivateKey "$ORDERER_TLS_PRIVATE_KEY" \
                '.[$ordKey] += {ordHost: $ordHost, listenAddress: $listenAddress, port: $port, address: $address, localMspId: $localMspId, adminListenAddress: $adminListenAddress, tlsCa: $tlsCa, tlsSignCert: $tlsSignCert, tlsPrivateKey: $tlsPrivateKey}' \
                ${ORD_JSON_FILE} > ${ORD_JSON_FILE}.tmp && mv ${ORD_JSON_FILE}.tmp ${ORD_JSON_FILE}
            else
                echo "Warning: No orderer found for name $ORDERER_NAME"
            fi
        else
            echo "Unknown service type: $SERVICE_TYPE"
        fi
    done <<< "$SERVICES"
}