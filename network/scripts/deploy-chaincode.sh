#!/bin/bash

. cc-utils.sh

# Calculate the package ID for the chaincode
calculate_package_id

# Install chaincode on all peers using a for loop
ORG_COUNT=$(jq -r 'length' ${ORG_JSON_FILE})
for ((i=1; i<=ORG_COUNT; i++)); do
    PEER_COUNT=$(jq -r ".\"$i\".peers | length" ${ORG_JSON_FILE})
    for ((j=1; j<=PEER_COUNT; j++)); do
        peer_install_chaincode $i $j
    done
done

# Resolve the sequence for chaincode definition
resolveSequence
resolveVersion

# Approve chaincode
approve_chaincode

# Check commit readiness for all the organizations
check_commit_readiness

# Commit chaincode definition
commit_chaincode