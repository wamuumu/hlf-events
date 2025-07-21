#!/bin/bash

. ../network.config
. set-env.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

ORGANIZATIONS_JSON_FILE=${NETWORK_PROFILE_PATH}/organizations.json
ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})

CC_PACKAGE_PATH="${NETWORK_PACKAGE_PATH}/${CC_NAME}_${CC_VERSION}.tar.gz"

peer_install_chaincode() {
    set_organization_peer $1 $2
    
    echo "Installing chaincode on ${CORE_PEER_ADDRESS}..."
    peer lifecycle chaincode install ${CC_PACKAGE_PATH}
}

peer_approve_chaincode() {
    set_organization_peer $1 $2
    
    echo "Approving chaincode for ${CORE_PEER_ADDRESS}..."
    peer lifecycle chaincode approveformyorg \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_ADMIN_TLS_CA} \
        --channelID ${NETWORK_CHANNEL_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --package-id ${PACKAGE_ID} \
        --sequence ${CC_SEQUENCE}
}

peer_commit_chaincode() {

    PEER_ADDRESSES=""
    TLS_ROOT_CERT_FILES=""
    
    for ((i=1; i<=ORG_COUNT; i++)); do

        local organization=$(jq -r ".\"$i\"" ${ORGANIZATIONS_JSON_FILE})
        local peers_count=$(echo "$organization" | jq -r '.peers | length')

        # Loop through all peers in this organization
        for ((peer_num=1; peer_num<=peers_count; peer_num++)); do
            set_organization_peer $i $peer_num
            
            if [ ! -z "${PEER_ADDRESSES}" ]; then
                PEER_ADDRESSES="${PEER_ADDRESSES} --peerAddresses ${CORE_PEER_ADDRESS}"
                TLS_ROOT_CERT_FILES="${TLS_ROOT_CERT_FILES} --tlsRootCertFiles ${CORE_PEER_TLS_ROOTCERT_FILE}"
            else
                PEER_ADDRESSES="--peerAddresses ${CORE_PEER_ADDRESS}"
                TLS_ROOT_CERT_FILES="--tlsRootCertFiles ${CORE_PEER_TLS_ROOTCERT_FILE}"
            fi
        done
    done

    echo "Committing chaincode definition..."
    peer lifecycle chaincode commit \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_ADMIN_TLS_CA} \
        --channelID ${NETWORK_CHANNEL_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE} \
        ${PEER_ADDRESSES} \
        ${TLS_ROOT_CERT_FILES}        
}

# Calculate the package ID for the chaincode
PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_PACKAGE_PATH})
echo "Calculated package ID: ${PACKAGE_ID}"

# Install chaincode on all peers using a for loop
for ((i=1; i<=ORG_COUNT; i++)); do
    PEER_COUNT=$(jq -r ".\"$i\".peers | length" ${ORGANIZATIONS_JSON_FILE})
    for ((j=1; j<=PEER_COUNT; j++)); do
        peer_install_chaincode $i $j
    done
done
echo "Chaincode installed successfully on all peers."

# Set the orderer for approvals and commits
set_orderer 1 

# Approve chaincode for each organization
for ((i=1; i<=ORG_COUNT; i++)); do
    PEER_COUNT=$(jq -r ".\"$i\".peers | length" ${ORGANIZATIONS_JSON_FILE})
    for ((j=1; j<=PEER_COUNT; j++)); do
        peer_approve_chaincode $i $j
    done
done
echo "Chaincode approved for all organizations."

# Check commit readiness for all the organizations
peer lifecycle chaincode checkcommitreadiness \
    --channelID ${NETWORK_CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --output json

# Commit chaincode definition
peer_commit_chaincode
echo "Chaincode committed successfully on all peers."