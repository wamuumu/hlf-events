#!/bin/bash

. set-env.sh

generate_crypto() {

    local CRYPTO_CONFIG_FILE=$1

    cryptogen generate --config=${CRYPTO_CONFIG_FILE} --output=${NETWORK_ORG_PATH} > /dev/null 2>&1
    echo "Cryptographic material generated successfully in ${NETWORK_ORG_PATH}"
}

generate_ccp() {

    local crypto_config_file=$1
    local docker_compose_file=$2

    local org=$(yq -r '.PeerOrgs' ${crypto_config_file})

    if [ -z "$org" ] || [ "$org" == "null" ]; then
        echo "Skipping..."
        return
    fi

    org=$(echo "$org" | jq -r 'to_entries[0] | .value')

    local name=$(echo "$org" | jq -r '.Name')
    local domain=$(echo "$org" | jq -r '.Domain')
    local org_cert="${NETWORK_ORG_PATH}/peerOrganizations/${domain}/tlsca/tlsca.${domain}-cert.pem"

    org_ccp_file=${NETWORK_ORG_PATH}/peerOrganizations/${domain}/connection-${name,,}.json
    
    local services=$(yq -r '.services | to_entries | .[] | @json' ${docker_compose_file})
    while IFS= read -r service; do
        peer_local_mspid=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_LOCALMSPID=")) | sub("CORE_PEER_LOCALMSPID="; "")')
        if [ ! -f "$org_ccp_file" ]; then
            echo $(sed -e "s/\${ORG_NAME}/$name/" -e "s/\${MSPID}/$peer_local_mspid/" ../templates/ccp-template.json) > $org_ccp_file
        fi

        peer_hostname=$(echo "$service" | jq -r '.key')
        peer_listen_port=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_ADDRESS=")) | sub("CORE_PEER_ADDRESS="; "") | split(":") | .[-1]')
        peer_default_endpoint="${DEFAULT_ENDPOINT}:${peer_listen_port}"

        # Add peer_hostname to organizations->$name->peers array
        jq --arg peer "$peer_hostname" '.organizations."'"$name"'".peers += [$peer]' $org_ccp_file >> $org_ccp_file.tmp && mv $org_ccp_file.tmp $org_ccp_file

        # Add peer details to peers object
        jq --arg peer "$peer_hostname" \
           --arg url "grpcs://$peer_default_endpoint" \
           --arg pem "$org_cert" \
           '.peers += {($peer): {
               "url": $url,
               "tlsCACerts": {
                   "path": $pem
               },
               "grpcOptions": {
                   "ssl-target-name-override": $peer,
                   "hostnameOverride": $peer
               }
           }}' $org_ccp_file >> $org_ccp_file.tmp && mv $org_ccp_file.tmp $org_ccp_file

    done <<< "$services"

    echo "Organization-level CCP generated at $org_ccp_file"
}

delete_crypto() {

    local ORG_DOMAIN=$1

    rm -rf "${NETWORK_ORG_PATH}/peerOrganizations/${ORG_DOMAIN,,}"
    echo "Cryptographic material for organization ${ORG_DOMAIN} deleted successfully."
}


