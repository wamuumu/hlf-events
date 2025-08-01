#!/bin/bash

. set-env.sh

if [ ! -d "${NETWORK_LOG_PATH}/chaincode" ]; then
    mkdir -p "${NETWORK_LOG_PATH}/chaincode"
fi

calculate_package_id() {
    export PACKAGE_ID=$(peer lifecycle chaincode calculatepackageid ${CC_PKG_PATH})
    echo "Calculated package ID: ${PACKAGE_ID}"
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

get_tls_identities() {
    PEER_ADDRESSES=""
    TLS_ROOT_CERT_FILES=""

    ORG_COUNT=$(jq -r 'length' ${ORG_JSON_FILE})
    for ((i=1; i<=ORG_COUNT; i++)); do

        local organization=$(jq -r ".\"$i\"" ${ORG_JSON_FILE})
        local peers_count=$(echo "$organization" | jq -r '.peers | length')

        # TODO: only one peer per organization is needed (use anchors)
        for ((j=1; j<=peers_count; j++)); do
            set_organization_peer $i $j >> ${NETWORK_LOG_PATH}/chaincode/commit.log 2>&1

            PEER_ADDRESSES+="--peerAddresses ${CORE_PEER_ADDRESS} "
            TLS_ROOT_CERT_FILES+="--tlsRootCertFiles ${CORE_PEER_TLS_ROOTCERT_FILE} "
        done
    done

    return "${PEER_ADDRESSES}${TLS_ROOT_CERT_FILES}"
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

# TODO: add the peer lifecycle chaincode queryinstalled command to check if the chaincode is installed on the peer
# TODO: add the peer lifecycle chaincode querycommitted command to check if the chaincode is committed on the channel

install_chaincode() {
    local ORG_ID=$1
    if [ -z "$ORG_ID" ]; then
        echo "Usage: $0 <organization_id>"
        exit 1
    fi

    calculate_package_id

    # TODO: run on every peer of the organization
    PEER_COUNT=$(jq -r ".\"$ORG_ID\".peers | length" ${ORG_JSON_FILE})
    for ((i=1; i<=PEER_COUNT; i++)); do    
        set_organization_peer $1 $2 >> ${NETWORK_LOG_PATH}/chaincode/install.log 2>&1
        peer lifecycle chaincode install ${CC_PKG_PATH} >> ${NETWORK_LOG_PATH}/chaincode/install.log 2>&1
        echo "Chaincode installed on peer ${CORE_PEER_LOCALMSPID} (${CORE_PEER_ADDRESS})"
    done
    echo "Chaincode ${PACKAGE_ID} installed on all peers of organization ${ORG_ID}"
}

approve_chaincode() {
    local ORG_ID=$1
    if [ -z "$ORG_ID" ]; then
        echo "Usage: $0 <organization_id>"
        exit 1
    fi

    set_orderer ${DEFAULT_ORD} >> ${NETWORK_LOG_PATH}/chaincode/approve.log 2>&1
    set_organization_peer ${ORG_ID} ${ANCHOR_PEER} >> ${NETWORK_LOG_PATH}/chaincode/approve.log 2>&1

    resolveSequence

    peer lifecycle chaincode approveformyorg \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_ADMIN_TLS_CA} \
        --channelID ${NETWORK_CHN_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE} \
        >> ${NETWORK_LOG_PATH}/chaincode/approve.log 2>&1
    echo "Chaincode approved for organization ${ORG_ID}"
}

commit_chaincode() {
    
    TLS_IDENTITIES=$(get_tls_identities) #TODO: check if this works 

    resolveSequence
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
        ${TLS_IDENTITIES} \
        >> ${NETWORK_LOG_PATH}/chaincode/commit.log 2>&1
    echo "Chaincode committed successfully on all peers."  
}

invoke_chaincode() {

    # TODO: add params
    # TODO: single function for all invokations or separate? Maybe contract-utils.sh ?

    TIMESTAMP=$(date +%s)
    PID="pid_test"
    URI="https://example.com/resource/$PID"
    
    # Generate hash - use shasum on macOS, sha256sum on Linux
    if command -v sha256sum &> /dev/null; then
        HASH=$(echo -n "$PID$URI$TIMESTAMP" | sha256sum | cut -d' ' -f1)
    elif command -v shasum &> /dev/null; then
        HASH=$(echo -n "$PID$URI$TIMESTAMP" | shasum -a 256 | cut -d' ' -f1)
    else
        # Fallback to a simple hash
        HASH=$(echo -n "$PID$URI$TIMESTAMP" | od -An -tx1 | tr -d ' \n')
    fi
    
    # Construct the JSON payload properly
    JSON_PAYLOAD="{\"Function\":\"CreateResource\",\"Args\":[\"$PID\",\"$URI\",\"$HASH\",\"$TIMESTAMP\",\"[\\\"owner1\\\",\\\"owner2\\\"]\"]}"
    
    TLS_IDENTITIES=$(get_tls_identities)

    set_organization_peer ${DEFAULT_ORG} 1 >> ${NETWORK_LOG_PATH}/chaincode/invoke.log 2>&1 #TODO: pass org_id as param
    set_orderer ${DEFAULT_ORD} >> ${NETWORK_LOG_PATH}/chaincode/invoke.log 2>&1
    peer chaincode invoke \
        -o $ORDERER_ADDR \
        -C $NETWORK_CHN_NAME \
        -n $CC_NAME \
        --tls \
        --cafile $ORDERER_ADMIN_TLS_CA \
        ${TLS_IDENTITIES} \
        -c "$JSON_PAYLOAD" \
        >> ${NETWORK_LOG_PATH}/chaincode/invoke.log 2>&1
    echo "Chaincode invoked successfully. Payload:"
    echo "$JSON_PAYLOAD" | jq .
}

# query_chaincode() {
#     # TODO: implement
# }