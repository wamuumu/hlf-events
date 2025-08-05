#!/bin/bash

. network-utils.sh

ORG_DOMAIN=$1
PEER_ID=$2

# Check if the required parameters are provided
if [ -z "${ORG_DOMAIN}" ] || [ -z "${PEER_ID}" ]; then
    echo "Usage: $0 <org_domain> <peer_id>"
    exit 1
fi

# Set the anchor peer for the specified organization
set_anchor_peer ${ORG_DOMAIN} ${PEER_ID}