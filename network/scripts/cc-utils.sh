#!/bin/bash

. set-env.sh

mkdir -p ${NETWORK_LOG_PATH}/chaincode

calculate_package_id() {
    export PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_PKG_PATH})
    echo "Calculated package ID: ${PACKAGE_ID}"
}

peer_install_chaincode() {
    set_organization_peer $1 $2 >> ${NETWORK_LOG_PATH}/chaincode/install.log 2>&1
    peer lifecycle chaincode install ${CC_PKG_PATH} >> ${NETWORK_LOG_PATH}/chaincode/install.log 2>&1
    echo "Chaincode installed on peer ${CORE_PEER_LOCALMSPID} (${CORE_PEER_ADDRESS})"
}

approve_chaincode() {

    set_orderer ${DEFAULT_ORD} >> ${NETWORK_LOG_PATH}/chaincode/approve.log 2>&1

    ORG_COUNT=$(jq -r 'length' ${ORG_JSON_FILE})

    for ((i=1; i<=ORG_COUNT; i++)); do
        set_organization_peer $i 1 >> ${NETWORK_LOG_PATH}/chaincode/approve.log 2>&1

        peer lifecycle chaincode approveformyorg \
            -o ${ORDERER_ADDR} \
            --ordererTLSHostnameOverride ${ORDERER_HOST} \
            --tls \
            --cafile ${ORDERER_ADMIN_TLS_CA} \
            --channelID ${NETWORK_CHN_NAME} \
            --name ${CC_NAME} \
            --version ${CC_VERSION} \
            --package-id ${PACKAGE_ID} \
            --sequence ${CC_SEQUENCE} \
            >> ${NETWORK_LOG_PATH}/chaincode/approve.log 2>&1
        echo "Chaincode approved for organization ${CORE_PEER_LOCALMSPID}"
    done
}

resolveSequence() {
    COMMITTED_CC_SEQUENCE=$(peer lifecycle chaincode querycommitted --channelID $NETWORK_CHN_NAME --name ${CC_NAME} 2>/dev/null | sed -n "/Version:/{s/.*Sequence: //; s/, Endorsement Plugin:.*$//; p;}")
    
    if [ -z "$COMMITTED_CC_SEQUENCE" ]; then
        export CC_SEQUENCE=1
    else
        APPROVED_CC_SEQUENCE=$(peer lifecycle chaincode queryapproved --channelID $NETWORK_CHN_NAME --name ${CC_NAME} 2>/dev/null | sed -n "/sequence:/{s/^sequence: //; s/, version:.*$//; p;}")

        if [ -z "$APPROVED_CC_SEQUENCE" ] || [ "$COMMITTED_CC_SEQUENCE" == "$APPROVED_CC_SEQUENCE" ]; then
            export CC_SEQUENCE=$((COMMITTED_CC_SEQUENCE+1))
        else
            export CC_SEQUENCE=$APPROVED_CC_SEQUENCE
        fi
    fi

    echo "Resolved chaincode sequence: ${CC_SEQUENCE}"
}

resolveVersion() {
    export CC_VERSION=$(echo "$PACKAGE_ID" | sed -E 's/^.*_([^:]+):.*$/\1/')
    echo "Resolved chaincode version: ${CC_VERSION}"
}

check_commit_readiness() {
    peer lifecycle chaincode checkcommitreadiness \
        --channelID ${NETWORK_CHN_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE} \
        --output json \
        >> ${NETWORK_LOG_PATH}/chaincode/readiness.log 2>&1
}

commit_chaincode() {

    PEER_ADDRESSES=""
    TLS_ROOT_CERT_FILES=""
    
    ORG_COUNT=$(jq -r 'length' ${ORG_JSON_FILE})
    for ((i=1; i<=ORG_COUNT; i++)); do

        local organization=$(jq -r ".\"$i\"" ${ORG_JSON_FILE})
        local peers_count=$(echo "$organization" | jq -r '.peers | length')

        for ((j=1; j<=peers_count; j++)); do
            set_organization_peer $i $j >> ${NETWORK_LOG_PATH}/chaincode/commit.log 2>&1

            PEER_ADDRESSES+=" --peerAddresses ${CORE_PEER_ADDRESS}"
            TLS_ROOT_CERT_FILES+=" --tlsRootCertFiles ${CORE_PEER_TLS_ROOTCERT_FILE}"
        done
    done

    set_orderer ${DEFAULT_ORD} >> ${NETWORK_LOG_PATH}/chaincode/commit.log 2>&1
    peer lifecycle chaincode commit \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_ADMIN_TLS_CA} \
        --channelID ${NETWORK_CHN_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE} \
        ${PEER_ADDRESSES} \
        ${TLS_ROOT_CERT_FILES} \
        >> ${NETWORK_LOG_PATH}/chaincode/commit.log 2>&1
    echo "Chaincode committed successfully on all peers."      
}