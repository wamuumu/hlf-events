#!/bin/bash

. set-env.sh
    
CC_PACKAGE_PATH="${NETWORK_PACKAGE_PATH}/${CC_NAME}_${CC_VERSION}.tar.gz"

calculate_package_id() {
    set_organization_peer 1 1
    echo "Calculating package ID for ${CC_NAME} on ${PEER_NAME}..."
    export SINGULARITYENV_CC_PACKAGE_PATH="/etc/hyperledger/fabric/chaincode/${CC_NAME}_${CC_VERSION}.tar.gz"
    export PACKAGE_ID=$(singularity exec instance://${PEER_NAME} peer lifecycle chaincode calculatepackageid ${CC_PACKAGE_PATH})
    echo "Package ID for ${CC_NAME}: ${PACKAGE_ID}"
}

peer_install_chaincode() {
    set_organization_peer $1 $2
    echo "Installing chaincode on ${PEER_NAME}..."
    export SINGULARITYENV_CC_PACKAGE_PATH="/etc/hyperledger/fabric/chaincode/${CC_NAME}_${CC_VERSION}.tar.gz"
    singularity exec instance://${PEER_NAME} peer lifecycle chaincode install ${CC_PACKAGE_PATH} > ${LOGS}/${PEER_NAME}-install.log 2>&1
    echo "Chaincode installed on ${PEER_NAME} successfully."
}

function resolveSequence() {

    set_organization_peer 1 1

    echo "Resolving chaincode sequence for ${CC_NAME}..."

    export SINGULARITYENV_CHANNEL_NAME=${NETWORK_CHANNEL_NAME}
    export SINGULARITYENV_CC_NAME=${CC_NAME}

    COMMITTED_CC_SEQUENCE=$(singularity exec instance://${PEER_NAME} peer lifecycle chaincode querycommitted --channelID ${CHANNEL_NAME} --name ${CC_NAME} 2>/dev/null | sed -n "/Version:/{s/.*Sequence: //; s/, Endorsement Plugin:.*$//; p;}")
    
    # if there are no committed versions, then set the sequence to 1
    if [ -z "$COMMITTED_CC_SEQUENCE" ]; then
        CC_SEQUENCE=1
    else
        APPROVED_CC_SEQUENCE=$(singularity exec instance://${PEER_NAME} peer lifecycle chaincode queryapproved --channelID ${CHANNEL_NAME} --name ${CC_NAME} 2>/dev/null | sed -n "/sequence:/{s/^sequence: //; s/, version:.*$//; p;}")

        if [ -z "$APPROVED_CC_SEQUENCE" ] || [ "$COMMITTED_CC_SEQUENCE" == "$APPROVED_CC_SEQUENCE" ]; then
            CC_SEQUENCE=$((COMMITTED_CC_SEQUENCE+1))
        else
            CC_SEQUENCE=$APPROVED_CC_SEQUENCE
        fi
    fi

    export CC_SEQUENCE
    echo "Resolved chaincode sequence: ${CC_SEQUENCE}"
}

approve_chaincode() {

    ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})
    
    # Set the orderer for approvals
    set_orderer 1 

    for ((i=1; i<=ORG_COUNT; i++)); do
        set_organization_peer $i 1

        echo "[$PEER_NAME] Approving chaincode for organization $i..."

        export SINGULARITYENV_CHANNEL_NAME=${NETWORK_CHANNEL_NAME}
        export SINGULARITYENV_CC_NAME=${CC_NAME}
        export SINGULARITYENV_CC_VERSION=${CC_VERSION}
        export SINGULARITYENV_PACKAGE_ID=${PACKAGE_ID}
        export SINGULARITYENV_CC_SEQUENCE=${CC_SEQUENCE}

        singularity exec instance://${PEER_NAME} peer lifecycle chaincode approveformyorg \
            -o ${ORDERER_ADDR} \
            --ordererTLSHostnameOverride ${ORDERER_HOST} \
            --tls \
            --cafile ${ORDERER_ADMIN_TLS_CA} \
            --channelID ${CHANNEL_NAME} \
            --name ${CC_NAME} \
            --version ${CC_VERSION} \
            --package-id ${PACKAGE_ID} \
            --sequence ${CC_SEQUENCE} > ${LOGS}/${PEER_NAME}-approve.log 2>&1
        
        echo "Chaincode approved for organization $i on ${PEER_NAME}."
    done
}

check_commit_readiness() {

    set_organization_peer 1 1

    export SINGULARITYENV_CHANNEL_NAME=${NETWORK_CHANNEL_NAME}
    export SINGULARITYENV_CC_NAME=${CC_NAME}
    export SINGULARITYENV_CC_VERSION=${CC_VERSION}
    export SINGULARITYENV_CC_SEQUENCE=${CC_SEQUENCE}

    singularity exec instance://${PEER_NAME} peer lifecycle chaincode checkcommitreadiness \
        --channelID ${CHANNEL_NAME} \
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
        local org_name=$(echo "$organization" | jq -r '.orgName | ascii_downcase')
        local peers_count=$(echo "$organization" | jq -r '.peers | length')

        # Loop through all peers in this organization
        for ((j=1; j<=peers_count; j++)); do
            set_organization_peer $i $j
            PEER_ADDRESSES+=" --peerAddresses ${CORE_PEER_ADDRESS}"
        done

        TLS_ROOT_CERT_FILES+=" --tlsRootCertFiles /etc/hyperledger/fabric/tlsca/cert-${org_name}.pem"
    done

    # Set the peer and orderer for committing
    set_organization_peer 1 1
    set_orderer 1

    export SINGULARITYENV_CHANNEL_NAME=${NETWORK_CHANNEL_NAME}
    export SINGULARITYENV_CC_NAME=${CC_NAME}
    export SINGULARITYENV_CC_VERSION=${CC_VERSION}
    export SINGULARITYENV_CC_SEQUENCE=${CC_SEQUENCE}
    export SINGULARITYENV_PEER_ADDRESSES=${PEER_ADDRESSES}
    export SINGULARITYENV_TLS_ROOT_CERT_FILES=${TLS_ROOT_CERT_FILES}

    echo "Committing chaincode definition..."
    singularity exec instance://${PEER_NAME} peer lifecycle chaincode commit \
        -o ${ORDERER_ADDR} \
        --ordererTLSHostnameOverride ${ORDERER_HOST} \
        --tls \
        --cafile ${ORDERER_ADMIN_TLS_CA} \
        --channelID ${CHANNEL_NAME} \
        --name ${CC_NAME} \
        --version ${CC_VERSION} \
        --sequence ${CC_SEQUENCE} \
        ${PEER_ADDRESSES} \
        ${TLS_ROOT_CERT_FILES} > ${LOGS}/${PEER_NAME}-commit.log 2>&1
    echo "Chaincode committed successfully by ${PEER_NAME}."       
}