#!/bin/bash

. ../network.config
. set-env.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

CC_PACKAGE_PATH="${NETWORK_PACKAGE_PATH}/${CC_NAME}_${CC_VERSION}.tar.gz"

peer_install_chaincode() {
    local org_id=$1
    set_organization "$org_id"
    
    echo "Installing chaincode on ${CORE_PEER_ADDRESS}..."
    peer lifecycle chaincode install ${CC_PACKAGE_PATH}
}

peer_approve_chaincode() {
    local org_id=$1
    set_organization "$org_id"
    
    echo "Approving chaincode for ${CORE_PEER_ADDRESS}..."
    peer lifecycle chaincode approveformyorg \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_CA} \
        --channelID ${NETWORK_CHANNEL_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --package-id ${PACKAGE_ID} \
        --sequence ${CC_SEQUENCE}
}

peer_commit_chaincode() {

    PEER_ADDRESSES=""
    TLS_ROOT_CERT_FILES=""
    
    for i in "${!PEERS[@]}"; do
        local peer="${PEERS[$i]}"
        local peer_ca="${PEERS_CA[$i]}"
        
        if [ ! -z "${PEER_ADDRESSES}" ]; then
            PEER_ADDRESSES="${PEER_ADDRESSES} --peerAddresses ${peer}"
            TLS_ROOT_CERT_FILES="${TLS_ROOT_CERT_FILES} --tlsRootCertFiles ${peer_ca}"
        else
            PEER_ADDRESSES="--peerAddresses ${peer}"
            TLS_ROOT_CERT_FILES="--tlsRootCertFiles ${peer_ca}"
        fi
    done

    echo "Committing chaincode definition..."
    peer lifecycle chaincode commit \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_CA} \
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
peer_install_chaincode 1
peer_install_chaincode 2
peer_install_chaincode 3
echo "Chaincode installed successfully on all peers."

# Set the orderer for approvals and commits
set_orderer 1 

# Approve chaincode for each organization
peer_approve_chaincode 1
peer_approve_chaincode 2
peer_approve_chaincode 3
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