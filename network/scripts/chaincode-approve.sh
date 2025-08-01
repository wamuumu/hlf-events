#!/bin/bash

. cc-utils.sh

# Set the default orderer and peer
set_orderer ${DEFAULT_ORD}
set_peer ${DEFAULT_PEER}

# Resolve the sequence number for the chaincode
resolveSequence

# Approve the chaincode for the organization
approve_chaincode