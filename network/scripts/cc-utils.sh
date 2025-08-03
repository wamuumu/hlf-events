#!/bin/bash

. ids-utils.sh

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

check_commit_readiness() {
    peer lifecycle chaincode checkcommitreadiness \
        --channelID ${NETWORK_CHN_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE} \
        --output json
}

install_chaincode() {

    local org_domain=$1
    local endpoints_file="${NETWORK_IDS_PATH}/peerOrganizations/${org_domain}/endpoints.json"
    local peers_count=$(jq -r "keys | length" ${endpoints_file})

    for ((i=1; i<=peers_count; i++)); do
        set_peer ${org_domain} ${i}
        peer lifecycle chaincode install ${CC_PKG_PATH}
        if [ $? -ne 0 ]; then
            echo "Failed to install chaincode on peer $i"
            exit 1
        fi
    done
}

approve_chaincode() {
    peer lifecycle chaincode approveformyorg \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
        --tls \
        --cafile ${ORDERER_TLS_CA} \
        --channelID ${NETWORK_CHN_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE}
    echo "Chaincode approved for organization ${CORE_PEER_LOCALMSPID}."
}

commit_chaincode() {
    
    local tls_identities=$(get_tls_identities)

    peer lifecycle chaincode commit \
        -o ${ORDERER_ADDRESS} \
        --ordererTLSHostnameOverride ${ORDERER_HOSTNAME} \
        --tls \
        --cafile ${ORDERER_TLS_CA} \
        --channelID ${NETWORK_CHN_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE} \
        ${tls_identities}
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