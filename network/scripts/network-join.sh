#!/bin/bash

. crypto-utils.sh
. ids-utils.sh
. network-utils.sh
. update-config.sh
. cc-utils.sh

# Params definition
ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})
ORG_ID=$(($ORG_COUNT + 1))
CRYPTO_FILE=${NETWORK_CFG_PATH}/$1
CONFIGTX_FILE=${NETWORK_CFG_PATH}/$2
COMPOSE_FILE=${NETWORK_CMP_PATH}/$3

# Variables extraction from configuration files
ORG_NAME=$(yq -r '.PeerOrgs[0].Name' ${CRYPTO_FILE})
ORG_DOMAIN=$(yq -r '.PeerOrgs[0].Domain' ${CRYPTO_FILE})

function deploy_chaincode() {
    echo "Deploying chaincode ${CC_NAME} on organization ${ORG_NAME}"

    # Install chaincode on all new peers
    PEER_COUNT=$(jq -r ".\"$ORG_ID\".peers | length" ${ORGANIZATIONS_JSON_FILE})
    for ((i=1; i<=PEER_COUNT; i++)); do
        peer_install_chaincode $ORG_ID $i
    done
    echo "Chaincode installed successfully on all new peers."

    resolveSequence

    # Set the orderer for approvals and commits
    set_orderer 1 

    approve_chaincode
    echo "Chaincode approved for all organizations."

    # Check commit readiness for all the organizations
    check_commit_readiness

    # Commit chaincode definition
    commit_chaincode
    echo "Chaincode committed successfully on all peers."
}

add_organization ${ORG_ID} ${ORG_NAME} ${ORG_DOMAIN} ${COMPOSE_FILE}
generate_crypto ${CRYPTO_FILE}
generate_definition ${ORG_NAME} ${ORG_DOMAIN} ${CONFIGTX_FILE}

docker compose -f ${COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} up -d --no-recreate

join_organization
set_anchor_peer
deploy_chaincode

echo "Organization ${ORG_NAME} has been successfully added to the network."
