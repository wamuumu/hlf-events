#!/bin/bash

# Load network configuration variables
. network-utils.sh

echo "Using Fabric version: ${FABRIC_VERSION}"

# Pull required images if not already present
pull_if_missing fabric-orderer "$FABRIC_VERSION"
pull_if_missing fabric-peer    "$FABRIC_VERSION"

create_folders
init_profiles

# Create orderer instances
create_orderer_instance orderer1
create_orderer_instance orderer2

# Start orderers
sudo fuser -k 7050/tcp 7053/tcp 9443/tcp 8050/tcp 8053/tcp 9444/tcp 2>/dev/null || true #TODO: remove this
start_orderer_instance orderer1 0.0.0.0 7050 7053 9443
start_orderer_instance orderer2 0.0.0.0 8050 8053 9444

# # # Create peer instances
create_peer_instance peer0 org1
create_peer_instance peer0 org2
create_peer_instance peer0 org3

# # # Start peers
sudo fuser -k 7051/tcp 7052/tcp 9445/tcp 8051/tcp 8052/tcp 9446/tcp 9051/tcp 9052/tcp 9447/tcp 2>/dev/null || true #TODO: remove this
start_peer_instance peer0 org1 0.0.0.0 7051 7052 9445
start_peer_instance peer0 org2 0.0.0.0 8051 8052 9446
start_peer_instance peer0 org3 0.0.0.0 9051 9052 9447

echo
echo "All containers started successfully!"
echo " • List: singularity instance list"
echo " • Stop: ./network-down.sh"

# TODO: convert all hostnames and enpoints to localhost, otherwise containers cannot communicate with each other