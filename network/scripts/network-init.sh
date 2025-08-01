#!/bin/bash

. crypto-utils.sh
. network-utils.sh
. ids-utils.sh

# Force create the necessary directories
rm -rf ${NETWORK_ORG_PATH} ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH}
mkdir -p ${NETWORK_ORG_PATH} ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH}

# Generate the crypto material
generate_crypto ${CRYPTO_CONFIG_FILE}

# Generate the genesis block
generate_genesis ${CONFIGTX_FILE}

# Generate the orderer identities
generate_orderers ${ORDERER_COMPOSE_FILES[@]}
generate_organizations ${CRYPTO_CONFIG_FILE}
generate_peers ${ORGANIZATION_COMPOSE_FILES[@]}