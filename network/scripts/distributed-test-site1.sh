#!/bin/bash

. set-env.sh

# ---- For test only ----
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org1.yaml" --hard 
# -----------------------

#rm -rf ${NETWORK_ORG_PATH} ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH}
#mkdir -p ${NETWORK_ORG_PATH} ${NETWORK_CHN_PATH} ${NETWORK_IDS_PATH}

# -----------------------

# Setup the crypto material
#./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-ord1.yaml" "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml"
#./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-ord2.yaml" "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml"
#./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-org1.yaml" "${NETWORK_CMP_PATH}/docker-compose-org1.yaml"


# NOTE: This needs to be done only once, when all the crypto material is generated and shared.
# NOTE: Identities folder must exist and be populated with certificates.
#./network-init.sh

# Docker setup
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml" # Start the orderer 1
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml" # Start the orderer 2
./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-org1.yaml" # Start the organization 1

# Channel setup
./network-join-orderer.sh "orderer.ord1.testbed.local"  # TODO: set identity as environment variable
./network-join-orderer.sh "orderer.ord2.testbed.local"  # TODO: set identity as environment variable
./network-join-organization.sh "org1.testbed.local"     # TODO: set identity as environment variable

sleep 5
# Install the chaincode on all peers of all organizations
./chaincode-install.sh "org1.testbed.local" # TODO: set identity as environment variable

# Approve the chaincode for each organization (only once)
./chaincode-approve.sh "org1.testbed.local" # TODO: set identity as environment variable

# Commit the chaincode definition to the channel (only once)
./chaincode-commit.sh "org1.testbed.local" # TODO: set identity as environment variable

# Test the chaincode invocation
./chaincode-invoke.sh "org1.testbed.local" 1  # TODO: set identity as environment variable

read -p "Do steps 1 and 2 from the second site, make sure to put the new identity json in the correct location, then press Enter to continue..."


# Now, organization 4 wants to join the network (the flow of actions is strictly defined and must be followed in this order):
# 1. The new organization needs to create its credentials and public identity
# 2. The new organization starts its containers
# 3. A network participant needs to create a join request for the new organization
# 4. The participant needs to approve the join request by signing it
# 5. A participant needs to submit the join request to the orderer
# 6. The new organization needs to join the channel
# 7. The new organization needs to set the anchor peer
# 8. The new organization needs to install the chaincode
# 9. All the organizations need to approve the chaincode
# 10. Commit the chaincode (only one) to include the new organization in the endorsment policy (i.e. use the chaincode)

# 1. Credentials and public identity creation

# 2. Start the containers for organization 4

# 3. Create a join request for the new organization
./network-join-request.sh "${NETWORK_CTX_PATH}/org4/configtx.yaml" "org1.testbed.local" # TODO: set identity as environment variable

# 4. Approve the join request by signing it
./network-approve-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable

# 5. Submit the join request to the orderer (only once)
./network-commit-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable

read -p "Do steps 6, 7 and 8 from the second site and then press Enter to continue..."

# 6. The new organization 4 needs to join the channel and install the chaincode

# 7. Set the anchor peer for organization 4 [to match the gossip bootstrap address in the compose file]

# 8. Install and approve the chaincode for organization 4

# 9. Approve the chaincode for all organizations
./chaincode-approve.sh "org1.testbed.local"          # TODO: set identity as environment variable

read -p "Do step 9 and 10 from the second site and then press Enter to continue..."

# 10. Commit the chaincode to include the new organization in the endorsement policy

# Test the chaincode invocation with the new organization

#read -p "The test is complete, proceed with requesting the removal of the org4 from second site, put the updated config in the correct location, then press enter to approve the removal"
# Remove the new organization 4 from the network

# Approve the removal of organization 4 from the channel
#./network-approve-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable

# Commit the removal of organization 4 from the channel
#./network-commit-update.sh "${NETWORK_CHN_PATH}/org4_update_in_envelope.pb" "org1.testbed.local" # TODO: set identity as environment variable

#read -p "The removal request is committed, org4 can now leave the network..."
# Remove the organization 4 crypto material and public identity

# Stop the organization 4 containers
read -p "Testbed complete, removing containers..."

# ---- For test only ----
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord1.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-ord2.yaml" --hard
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org1.yaml" --hard
# -----------------------