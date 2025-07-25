#!/bin/bash

. ../network.config

# Files
CRYPTO_CONFIG_FILE=${FABRIC_CFG_PATH}/crypto-config.yaml

# Pull & convert to sandbox folder if missing
pull_if_missing() {
    local name=$1 tag=$2 
    local sandbox="${SAND}/${name}"
    local tarball="${SAND}/${name}.tar"

    if ! [[ -d "$SAND" ]]; then
        mkdir -p "$SAND"
    fi

    if [[ -d "$sandbox" ]]; then
        echo "$sandbox already exists, skipping."
        return
    fi

    # 1. Pull the Docker image if not present
    docker pull hyperledger/${name}:${tag} # TODO: we're using singularity, so what if docker is missing?

    # 2. Save it to a tarball
    docker save hyperledger/${name}:${tag} -o ${tarball}

    # 3. Convert the tarball to a sandbox folder
    # Note: --sandbox is used to create a writable directory structure, which enables older Singularity versions to run
    singularity build --sandbox ${sandbox} docker-archive://${tarball}

    # 4. Clean up the tarball
    rm -f "${tarball}"

    echo "Created sandbox at ${sandbox}"
}

# Prepare directories
create_folders() {
    mkdir -p "$DATA" "$LOGS"
    echo "Created data and logs directories at $DATA and $LOGS"

    # Create hosts file inside CONF
    HOST_FILE="$CONF/hosts"
    echo "127.0.0.1    localhost" > "$HOST_FILE"

    mkdir -p "$NETWORK_PROFILE_PATH"
    echo "Created network profile directory at $NETWORK_PROFILE_PATH"

    echo {} > "$ORGANIZATIONS_JSON_FILE"
    echo {} > "$ORDERERS_JSON_FILE"
    echo "Initialized JSON files: $ORGANIZATIONS_JSON_FILE and $ORDERERS_JSON_FILE"

    mkdir -p "$NETWORK_CHANNEL_PATH"
    echo "Created network channel path at $NETWORK_CHANNEL_PATH"
}

# Delete directories
delete_folders() {
    local force=$1

    if [[ "$force" = true ]]; then
        rm -rf "$SAND"
        echo "Deleted sandbox directory: $SAND"
    fi

    rm -rf "$DATA" "$LOGS" "$NETWORK_PROFILE_PATH" "$NETWORK_CHANNEL_PATH"
    echo "Deleted data, logs and network profile directories"
}

init_profiles() {
    ORGS=$(yq -r '.PeerOrgs' ${CRYPTO_CONFIG_FILE})
    for ORG in $(echo "${ORGS}" | jq -r 'keys[]'); do
        ORG_NAME=$(echo "${ORGS}" | jq -r ".[$ORG].Name")
        ORG_DOMAIN=$(echo "${ORGS}" | jq -r ".[$ORG].Domain")
        ORG_MSP=$ORG_NAME"MSP"

        ORG_ID=$(($(jq 'keys | length' ${ORGANIZATIONS_JSON_FILE}) + 1))
        jq \
            ".[\"$ORG_ID\"] = {orgName: \"$ORG_NAME\", orgDomain: \"$ORG_DOMAIN\", orgMSP: \"$ORG_MSP\", peers: []}" \
            ${ORGANIZATIONS_JSON_FILE} | sponge ${ORGANIZATIONS_JSON_FILE}

    done
    echo "Filled organizations profile in ${ORGANIZATIONS_JSON_FILE}"

    ORD_DOMAIN=$(yq -r '.OrdererOrgs[0].Domain' ${CRYPTO_CONFIG_FILE})
    ORDS=$(yq -r '.OrdererOrgs[0].Specs' ${CRYPTO_CONFIG_FILE})
    for ORD in $(echo "${ORDS}" | jq -r 'keys[]'); do
        ORD_NAME=$(echo "${ORDS}" | jq -r ".[$ORD].Hostname")
        ORD_HOST="${ORD_NAME}.${ORD_DOMAIN}"

        ORD_ID=$(($(jq 'keys | length' ${ORDERERS_JSON_FILE}) + 1))
        jq \
            ".[\"$ORD_ID\"] = {ordName: \"$ORD_NAME\", ordDomain: \"$ORD_DOMAIN\", ordHost: \"$ORD_HOST\"}" \
            ${ORDERERS_JSON_FILE} | sponge ${ORDERERS_JSON_FILE}
    done
    echo "Filled orderers profile in ${ORDERERS_JSON_FILE}"
}

# Helpers to create and start an orderer instance
create_orderer_instance() {

    local instance_name=$1

    local binddir=${DATA}/${instance_name}
    mkdir -p ${binddir}

    local sandbox="${SAND}/fabric-orderer"

    singularity instance start \
        --bind ${NETWORK_ORG_PATH}/ordererOrganizations/ord.testbed.local/orderers/${instance_name}.ord.testbed.local/msp:/var/hyperledger/orderer/msp:ro \
        --bind ${NETWORK_ORG_PATH}/ordererOrganizations/ord.testbed.local/orderers/${instance_name}.ord.testbed.local/tls:/var/hyperledger/orderer/tls:ro \
        --bind ${binddir}:/var/hyperledger/production/orderer \
        ${sandbox} ${instance_name}
}

start_orderer_instance() {
    
    local instance_name=$1
    local listen_port=$2
    local admin_port=$3
    local ops_port=$4

    export SINGULARITYENV_ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
    export SINGULARITYENV_ORDERER_GENERAL_LISTENPORT=${listen_port}
    export SINGULARITYENV_ORDERER_GENERAL_LOCALMSPID=OrdererMSP
    export SINGULARITYENV_ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp

    export SINGULARITYENV_ORDERER_GENERAL_TLS_ENABLED=true
    export SINGULARITYENV_ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
    export SINGULARITYENV_ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
    export SINGULARITYENV_ORDERER_GENERAL_TLS_ROOTCAS='[/var/hyperledger/orderer/tls/ca.crt]'

    export SINGULARITYENV_ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/var/hyperledger/orderer/tls/server.crt
    export SINGULARITYENV_ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/var/hyperledger/orderer/tls/server.key
    export SINGULARITYENV_ORDERER_GENERAL_CLUSTER_ROOTCAS='[/var/hyperledger/orderer/tls/ca.crt]'

    export SINGULARITYENV_ORDERER_GENERAL_BOOTSTRAPMETHOD=none
    export SINGULARITYENV_ORDERER_CHANNELPARTICIPATION_ENABLED=true

    export SINGULARITYENV_ORDERER_ADMIN_TLS_ENABLED=true
    export SINGULARITYENV_ORDERER_ADMIN_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
    export SINGULARITYENV_ORDERER_ADMIN_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
    export SINGULARITYENV_ORDERER_ADMIN_TLS_ROOTCAS='[/var/hyperledger/orderer/tls/ca.crt]'
    export SINGULARITYENV_ORDERER_ADMIN_TLS_CLIENTROOTCAS='[/var/hyperledger/orderer/tls/ca.crt]'
    export SINGULARITYENV_ORDERER_ADMIN_LISTENADDRESS=0.0.0.0:${admin_port}

    export SINGULARITYENV_ORDERER_OPERATIONS_LISTENADDRESS=0.0.0.0:${ops_port}
    export SINGULARITYENV_ORDERER_METRICS_PROVIDER=prometheus

    singularity exec instance://${instance_name} orderer > ${LOGS}/${instance_name}.log 2>&1 &

    # Fill the orderer profile
    ORD_KEY=$(jq -r "to_entries[] | select(.value.ordName == \"$instance_name\") | .key" ${ORDERERS_JSON_FILE})
    ORD_DOMAIN=$(jq -r "to_entries[] | select(.value.ordName == \"$instance_name\") | .value.ordDomain" ${ORDERERS_JSON_FILE})
    ORD_TLS_HOST=$(jq -r "to_entries[] | select(.value.ordName == \"$instance_name\") | .value.ordHost" ${ORDERERS_JSON_FILE})

    jq \
        --arg ordKey "$ORD_KEY" \
        --arg listenAddress "localhost:${listen_port}" \
        --arg localMspId "$SINGULARITYENV_ORDERER_GENERAL_LOCALMSPID" \
        --arg adminListenAddress "localhost:${admin_port}" \
        --arg tlsCa "${NETWORK_ORG_PATH}/ordererOrganizations/${ORD_DOMAIN}/tlsca/tlsca.${ORD_DOMAIN}-cert.pem" \
        --arg tlsSignCert "${NETWORK_ORG_PATH}/ordererOrganizations/${ORD_DOMAIN}/orderers/${ORD_TLS_HOST}/tls/server.crt" \
        --arg tlsPrivateKey "${NETWORK_ORG_PATH}/ordererOrganizations/${ORD_DOMAIN}/orderers/${ORD_TLS_HOST}/tls/server.key" \
        '.[$ordKey] += {listenAddress: $listenAddress, localMspId: $localMspId, adminListenAddress: $adminListenAddress, tlsCa: $tlsCa, tlsSignCert: $tlsSignCert, tlsPrivateKey: $tlsPrivateKey}' \
        ${ORDERERS_JSON_FILE} | sponge ${ORDERERS_JSON_FILE}
    echo "Updated orderer profile in ${ORDERERS_JSON_FILE} for ${instance_name}"
}

# Helpers to create and start a peer instance
create_peer_instance() {
    
    local peer_name=$1
    local org=$2

    local binddir=${DATA}/${peer_name}.${org}
    mkdir -p ${binddir}

    local sandbox="${SAND}/fabric-peer"
    
    singularity instance start \
        --bind ${NETWORK_ORG_PATH}/peerOrganizations/${org}.testbed.local/peers/${peer_name}.${org}.testbed.local/msp:/etc/hyperledger/fabric/msp:ro \
        --bind ${NETWORK_ORG_PATH}/peerOrganizations/${org}.testbed.local/peers/${peer_name}.${org}.testbed.local/tls:/etc/hyperledger/fabric/tls:ro \
        --bind ${FABRIC_CFG_PATH}/core.yaml:/etc/hyperledger/fabric/core.yaml:ro \
        --bind ${NETWORK_ORG_PATH}/peerOrganizations/${org}.testbed.local/users/Admin@${org}.testbed.local/msp:/etc/hyperledger/fabric/admin/msp:ro \
        --bind ${NETWORK_ORG_PATH}/peerOrganizations/${org}.testbed.local/users/Admin@${org}.testbed.local/tls:/etc/hyperledger/fabric/admin/tls:ro \
        --bind ${NETWORK_ORG_PATH}/peerOrganizations/${org}.testbed.local/tlsca/tlsca.${org}.testbed.local-cert.pem:/etc/hyperledger/fabric/tlsca/cert.pem:ro \
        --bind ${NETWORK_CHANNEL_PATH}:/etc/hyperledger/fabric/channel:ro \
        --bind ${binddir}:/var/hyperledger/production \
        ${sandbox} ${peer_name}.${org}
}

start_peer_instance() {
    local peer_name=$1
    local org=$2
    local listen_port=$3
    local cc_port=$4
    local ops_port=$5

    PEER_ORG_DOMAIN="${org}.testbed.local"
    PEER_HOSTNAME="${peer_name}.${PEER_ORG_DOMAIN}"
    PEER_INSTANCE="${peer_name}.${org}"

    echo "Starting ${PEER_INSTANCE}..."
    export SINGULARITYENV_FABRIC_CFG_PATH=/etc/hyperledger/fabric
    export SINGULARITYENV_FABRIC_LOGGING_SPEC=INFO
    export SINGULARITYENV_CORE_PEER_TLS_ENABLED=true
    export SINGULARITYENV_CORE_PEER_ID=${PEER_INSTANCE}
    export SINGULARITYENV_CORE_PEER_ADDRESS=${PEER_HOSTNAME}:${listen_port}
    export SINGULARITYENV_CORE_PEER_LISTENADDRESS=0.0.0.0:${listen_port}
    export SINGULARITYENV_CORE_PEER_CHAINCODEADDRESS=${PEER_HOSTNAME}:${cc_port}
    export SINGULARITYENV_CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:${cc_port}
    export SINGULARITYENV_CORE_PEER_GOSSIP_BOOTSTRAP=${PEER_HOSTNAME}:${listen_port}
    export SINGULARITYENV_CORE_PEER_GOSSIP_EXTERNALENDPOINT=${PEER_HOSTNAME}:${listen_port}
    export SINGULARITYENV_CORE_PEER_LOCALMSPID=${org^}MSP
    export SINGULARITYENV_CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp
    export SINGULARITYENV_CORE_OPERATIONS_LISTENADDRESS=0.0.0.0:${ops_port}
    export SINGULARITYENV_CORE_METRICS_PROVIDER=prometheus

    singularity exec instance://${PEER_INSTANCE} peer node start > ${LOGS}/${PEER_INSTANCE}.log 2>&1 &

    # Fill the peer profile
    ORG_KEY=$(jq -r "to_entries[] | select(.value.orgDomain == \"${PEER_ORG_DOMAIN}\") | .key" ${ORGANIZATIONS_JSON_FILE})
    jq \
        --arg orgKey "$ORG_KEY" \
        --arg peerName "${PEER_INSTANCE}" \
        --arg listenAddress "localhost:${listen_port}" \
        --arg localMspId "$SINGULARITYENV_CORE_PEER_LOCALMSPID" \
        '.[$orgKey].peers += [{peerName: $peerName, listenAddress: $listenAddress, localMspId: $localMspId}]' \
        ${ORGANIZATIONS_JSON_FILE} | sponge ${ORGANIZATIONS_JSON_FILE}
    echo "Updated peer profile in ${ORGANIZATIONS_JSON_FILE} for ${PEER_INSTANCE}"
}   