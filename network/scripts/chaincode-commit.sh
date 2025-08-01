#!/bin/bash

. cc-utils.sh

# Set the default orderer and peer
set_orderer ${DEFAULT_ORD}
set_peer ${DEFAULT_PEER}

# Resolve the sequence number for the chaincode
resolveSequence

# Check the commit readiness of the chaincode
check_commit_readiness

# Commit the chaincode
commit_chaincode