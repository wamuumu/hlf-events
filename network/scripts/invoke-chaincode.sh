#!/bin/bash

. ../network.config
. set-env.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

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

    set_organization 1
    set_orderer 1

    # Print params
    echo "Invoking chaincode with the following parameters:"
    echo "Orderer Address: $ORDERER_ADDR"
    echo "Channel Name: $NETWORK_CHANNEL_NAME"
    echo "Chaincode Name: $CC_NAME"
    echo "JSON Payload: $JSON_PAYLOAD"  

    peer chaincode invoke \
        -o $ORDERER_ADDR \
        -C $NETWORK_CHANNEL_NAME \
        -n $CC_NAME \
        --tls \
        --cafile $ORDERER_CA \
        ${PEER_ADDRESSES} \
        ${TLS_ROOT_CERT_FILES} \
        -c "$JSON_PAYLOAD"
}

invoke_resource_creation

