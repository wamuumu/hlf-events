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
        echo "Organization not found in the crypto config file."
        return
    fi

    org=$(echo "$org" | jq -r 'to_entries[0] | .value')

    local name=$(echo "$org" | jq -r '.Name')
    local mspid=$(echo "$org" | jq -r '.Name')MSP
    local domain=$(echo "$org" | jq -r '.Domain')

    org_ccp_file=${NETWORK_ORG_PATH}/peerOrganizations/${domain}/connection-${name,,}.json
    echo $(sed -e "s/\${ORG_NAME}/$name/" -e "s/\${MSPID}/$mspid/" ../templates/ccp-template.json) > $org_ccp_file

    local services=$(yq -r '.services | to_entries | .[] | @json' ${docker_compose_file})
    while IFS= read -r service; do
        peer_hostname=$(echo "$service" | jq -r '.key')
        peer_local_mspid=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_LOCALMSPID=")) | sub("CORE_PEER_LOCALMSPID="; "")')
        peer_listen_port=$(echo "$service" | jq -r '.value.environment[] | select(. | startswith("CORE_PEER_ADDRESS=")) | sub("CORE_PEER_ADDRESS="; "") | split(":") | .[-1]')
        peer_default_endpoint="${peer_hostname}:${peer_listen_port}"
        peer_cert=organizations/peerOrganizations/${domain}/tlsca/tlsca.${domain}-cert.pem

        # Add peer_hostname to organizations->$name->peers array
        jq --arg peer "$peer_hostname" '.organizations."'"$name"'".peers += [$peer]' $org_ccp_file >> $org_ccp_file.tmp && mv $org_ccp_file.tmp $org_ccp_file

        # Add peer details to peers object
        jq --arg peer "$peer_hostname" \
           --arg url "grpcs://$peer_default_endpoint" \
           --arg pem "$peer_cert" \
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


