#!/bin/bash

. set-env.sh

# ---- For test only ----
for compose_file in "${COMPOSE_FILES[@]}"; do
    ./docker-down.sh "${compose_file}" --hard
done

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
./network-join-orderer.sh "orderer1.ord1.testbed.local" # TODO: set variable as environment variable
./network-join-orderer.sh "orderer2.ord2.testbed.local" # TODO: set variable as environment variable
./network-join-organization.sh "org1.testbed.local"     # TODO: set variable as environment variable

exit 0

sleep 20

# Deploy the chaincode
./chaincode-install.sh # Install the chaincode on all peers
./chaincode-approve.sh # Approve the chaincode for the organization
./chaincode-commit.sh # Commit the chaincode definition to the channel 