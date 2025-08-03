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
./network-join-orderer.sh "orderer.ord1.testbed.local" # TODO: set variable as environment variable
./network-join-orderer.sh "orderer.ord2.testbed.local" # TODO: set variable as environment variable
./network-join-organization.sh "org1.testbed.local"     # TODO: set variable as environment variable
./network-join-organization.sh "org2.testbed.local"     # TODO: set variable as environment variable
./network-join-organization.sh "org3.testbed.local"     # TODO: set variable as environment variable


# Install the chaincode on all peers of all organizations
./chaincode-install.sh "org1.testbed.local" # TODO: set variable as environment variable
./chaincode-install.sh "org2.testbed.local" # TODO: set variable as environment variable
./chaincode-install.sh "org3.testbed.local" # TODO: set variable as environment variable

# Approve the chaincode for each organization (only once)
./chaincode-approve.sh "org1.testbed.local" # TODO: set variable as environment variable
./chaincode-approve.sh "org2.testbed.local" # TODO: set variable as environment variable
./chaincode-approve.sh "org3.testbed.local" # TODO: set variable as environment variable

exit 0

# Commit the chaincode definition to the channel (only once)
./chaincode-commit.sh "org1.testbed.local"  # TODO: set variable as environment variable