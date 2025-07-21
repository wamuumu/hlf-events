#!/bin/bash

. ../network.config
. set-env.sh

CC_PACKAGE_PATH="${NETWORK_PACKAGE_PATH}/${CC_NAME}_${CC_VERSION}.tar.gz"
PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_PACKAGE_PATH})

ORGANIZATIONS_JSON_FILE=${NETWORK_PROFILE_PATH}/organizations.json

peer_install_chaincode() {
    set_organization_peer $1 $2
    
    echo "Installing chaincode on ${CORE_PEER_ADDRESS}..."
    peer lifecycle chaincode install ${CC_PACKAGE_PATH}
}

approve_chaincode() {

    ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})

    for ((i=1; i<=ORG_COUNT; i++)); do
        set_organization_peer $i 1

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
    done
}

function resolveSequence() {
    COMMITTED_CC_SEQUENCE=$(peer lifecycle chaincode querycommitted --channelID $NETWORK_CHANNEL_NAME --name ${CC_NAME} 2>/dev/null | sed -n "/Version:/{s/.*Sequence: //; s/, Endorsement Plugin:.*$//; p;}")
    
    # if there are no committed versions, then set the sequence to 1
    if [ -z "$COMMITTED_CC_SEQUENCE" ]; then
        CC_SEQUENCE=1
    else
        APPROVED_CC_SEQUENCE=$(peer lifecycle chaincode queryapproved --channelID $NETWORK_CHANNEL_NAME --name ${CC_NAME} 2>/dev/null | sed -n "/sequence:/{s/^sequence: //; s/, version:.*$//; p;}")

        if [ -z "$APPROVED_CC_SEQUENCE" ] || [ "$COMMITTED_CC_SEQUENCE" == "$APPROVED_CC_SEQUENCE" ]; then
            CC_SEQUENCE=$((COMMITTED_CC_SEQUENCE+1))
        else
            CC_SEQUENCE=$APPROVED_CC_SEQUENCE
        fi
    fi

    export CC_SEQUENCE
    echo "Resolved chaincode sequence: ${CC_SEQUENCE}"
}

check_commit_readiness() {
    peer lifecycle chaincode checkcommitreadiness \
    --channelID ${NETWORK_CHANNEL_NAME} \
    --name ${CC_NAME} \
    --version ${CC_VERSION} \
    --sequence ${CC_SEQUENCE} \
    --output json
}

commit_chaincode() {

    ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})

    PEER_ADDRESSES=""
    TLS_ROOT_CERT_FILES=""
    
    for ((i=1; i<=ORG_COUNT; i++)); do

        local organization=$(jq -r ".\"$i\"" ${ORGANIZATIONS_JSON_FILE})
        local peers_count=$(echo "$organization" | jq -r '.peers | length')

        # Loop through all peers in this organization
        for ((j=1; j<=peers_count; j++)); do
            set_organization_peer $i $j
            
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