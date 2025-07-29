#!/bin/bash

. cc-utils.sh

ORG_COUNT=$(jq -r 'length' ${ORG_JSON_FILE})

# Function to invoke chaincode (create provenance)
invoke_resource_creation() {
    
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
    
    PEER_ADDRESSES=""
    TLS_ROOT_CERT_FILES=""

    for ((i=1; i<=ORG_COUNT; i++)); do

        local organization=$(jq -r ".\"$i\"" ${ORG_JSON_FILE})
        local peers_count=$(echo "$organization" | jq -r '.peers | length')

        for ((j=1; j<=peers_count; j++)); do
            set_organization_peer $i $j >> ${NETWORK_LOG_PATH}/chaincode/invoke.log 2>&1

            PEER_ADDRESSES+=" --peerAddresses ${CORE_PEER_ADDRESS}"
            TLS_ROOT_CERT_FILES+=" --tlsRootCertFiles ${CORE_PEER_TLS_ROOTCERT_FILE}"
        done
    done

    set_orderer ${DEFAULT_ORD} >> ${NETWORK_LOG_PATH}/chaincode/invoke.log 2>&1
    set_organization_peer ${DEFAULT_ORG} 1 >> ${NETWORK_LOG_PATH}/chaincode/invoke.log 2>&1

    peer chaincode invoke \
        -o $ORDERER_ADDR \
        -C $NETWORK_CHN_NAME \
        -n $CC_NAME \
        --tls \
        --cafile $ORDERER_ADMIN_TLS_CA \
        ${PEER_ADDRESSES} \
        ${TLS_ROOT_CERT_FILES} \
        -c "$JSON_PAYLOAD" \
        >> ${NETWORK_LOG_PATH}/chaincode/invoke.log 2>&1
    echo "Chaincode invoked successfully. Payload:"
    echo "$JSON_PAYLOAD" | jq .
}

invoke_resource_creation

