#!/bin/bash

. ../network.config
. set-env.sh
. cc-utils.sh

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

ORGANIZATIONS_JSON_FILE=${NETWORK_PROFILE_PATH}/organizations.json
ORG_COUNT=$(jq -r 'length' ${ORGANIZATIONS_JSON_FILE})

# Install chaincode on all peers using a for loop
for ((i=1; i<=ORG_COUNT; i++)); do
    PEER_COUNT=$(jq -r ".\"$i\".peers | length" ${ORGANIZATIONS_JSON_FILE})
    for ((j=1; j<=PEER_COUNT; j++)); do
        peer_install_chaincode $i $j
    done
done
echo "Chaincode installed successfully on all peers."

resolveSequence

# Set the orderer for approvals and commits
set_orderer 1 

# Approve chaincode
approve_chaincode
echo "Chaincode approved for all organizations."

# Check commit readiness for all the organizations
check_commit_readiness

# Commit chaincode definition
commit_chaincode
echo "Chaincode committed successfully on all peers."