#!/bin/bash

. set-env.sh

# ---- For test only ----
for compose_file in "${COMPOSE_FILES[@]}"; do
    ./docker-down.sh "${compose_file}" --hard
done

./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" --hard # Stop the containers for organization 4

rm -rf ${NETWORK_ORG_PATH} ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH}
mkdir -p ${NETWORK_ORG_PATH} ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH}

# -----------------------

# Setup the crypto material
for i in "${!CRYPTO_CONFIG_FILES[@]}"; do
    crypto_config_file="${CRYPTO_CONFIG_FILES[$i]}"
    docker_compose_file="${COMPOSE_FILES[$i]}"
    ./network-prep.sh "${crypto_config_file}" "${docker_compose_file}"
done

# NOTE: This needs to be done only once, when all the crypto material is generated and shared.
# NOTE: Identities folder must exist and be populated with certificates.
./network-init.sh

# Docker setup
for compose_file in "${COMPOSE_FILES[@]}"; do
    ./docker-up.sh "${compose_file}" # Initialize the containers
done

# Channel setup
./network-join-orderer.sh "orderer.ord1.testbed.local"  # TODO: set identity as environment variable
./network-join-orderer.sh "orderer.ord2.testbed.local"  # TODO: set identity as environment variable
./network-join-organization.sh "org1.testbed.local"     # TODO: set identity as environment variable
./network-join-organization.sh "org2.testbed.local"     # TODO: set identity as environment variable
./network-join-organization.sh "org3.testbed.local"     # TODO: set identity as environment variable


# Install the chaincode on all peers of all organizations
./chaincode-install.sh "org1.testbed.local" # TODO: set identity as environment variable
./chaincode-install.sh "org2.testbed.local" # TODO: set identity as environment variable
./chaincode-install.sh "org3.testbed.local" # TODO: set identity as environment variable

# Approve the chaincode for each organization (only once)
./chaincode-approve.sh "org1.testbed.local" # TODO: set identity as environment variable
./chaincode-approve.sh "org2.testbed.local" # TODO: set identity as environment variable
./chaincode-approve.sh "org3.testbed.local" # TODO: set identity as environment variable

# Commit the chaincode definition to the channel (only once)
./chaincode-commit.sh "org1.testbed.local"  # TODO: set identity as environment variable

# Now, organization 4 wants to join the network (the flow of actions is strictly defined and must be followed in this order):
# 1. The new organization needs to create its credentials and public identity
# 2. The new organization starts its containers
# 3. A network participant needs to create a join request for the new organization
# 4. The participant needs to approve the join request by signing it
# 5. A participant needs to submit the join request to the orderer
# 6. The new organization needs to join the channel
# 7. The new organization needs to set the anchor peer
# 8. The new organization needs to install and approve the chaincode in order to use it

# 1. Credentials and public identity creation
./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-org4.yaml" "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" # Done by organization 4

# 2. Start the containers for organization 4
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" # Start the containers for organization 4

# 3. Create a join request for the new organization
./network-create-join-request.sh "${NETWORK_CTX_PATH}/configtx-org4.yaml" "org1.testbed.local" # TODO: set identity as environment variable

# 4. Approve the join request by signing it
./network-approve-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable
./network-approve-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org2.testbed.local" # TODO: set identity as environment variable
./network-approve-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org3.testbed.local" # TODO: set identity as environment variable

# 5. Submit the join request to the orderer (only once)
./network-commit-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable

# 6. The new organization 4 needs to join the channel and install the chaincode
./network-join-organization.sh "org4.testbed.local" # TODO: set identity as environment variable

# 7. Set the anchor peer for organization 4 [Optional, but recommended to avoid issues]

# 8. Install and approve the chaincode for organization 4
./chaincode-install.sh "org4.testbed.local"         # TODO: set identity as environment variable
./chaincode-approve.sh "org4.testbed.local"         # TODO: set identity as environment variable