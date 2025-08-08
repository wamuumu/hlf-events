#!/bin/bash

. set-env.sh

# ---- For test only ----
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" --hard 
# -----------------------
read -p "Make sure to cpy the crypto/identities material from the network to the correct location..."


# 1. Credentials and public identity creation
#./network-prep.sh "${NETWORK_CRP_PATH}/crypto-config-org4.yaml" "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" # Done by organization 4

# 2. Start the containers for organization 4
#./docker-up.sh "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" # Start the containers for organization 4

read -p "Proceed on main site with join request"

# 3. Create a join request for the new organization

# 4. Approve the join request by signing it

# 5. Submit the join request to the orderer (only once)

# 6. The new organization 4 needs to join the channel and install the chaincode
./network-join-organization.sh "org4.testbed.local" # TODO: set identity as environment variable

# 7. Set the anchor peer for organization 4 [to match the gossip bootstrap address in the compose file]
./network-set-anchor-peer.sh "org4.testbed.local" 1 # TODO: set identity as environment variable, assuming peer ID 1 is the anchor peer

# 8. Install and approve the chaincode for organization 4
./chaincode-install.sh "org4.testbed.local"          # TODO: set identity as environment variable

read -p "Approve chaincode from main site"

# 9. Approve the chaincode for all organizations
./chaincode-approve.sh "org4.testbed.local"          # TODO: set identity as environment variable

# 10. Commit the chaincode to include the new organization in the endorsement policy
./chaincode-commit.sh "org4.testbed.local"           # TODO: set identity as environment variable

# Test the chaincode invocation with the new organization
./chaincode-invoke.sh "org4.testbed.local" 1         # TODO: set identity as environment variable

#read -p "Press enter to request to leave the network"

# Remove the new organization 4 from the network
#./network-leave-request.sh "${NETWORK_CTX_PATH}/org4/configtx.yaml" "org4.testbed.local" # TODO: set identity as environment variable

# Approve the removal of organization 4 from the channel

# Commit the removal of organization 4 from the channel

#read -p "Press enter to leave the network"
# Remove the organization 4 crypto material and public identity
#./network-leave-organization.sh "org4.testbed.local" --hard     # TODO: set identity as environment variable

# Stop the organization 4 containers
#./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org4.yaml"

read -p "Press enter to close the network"
# ---- For test only ----
./docker-down.sh "${NETWORK_CMP_PATH}/docker-compose-org4.yaml" --hard
# -----------------------