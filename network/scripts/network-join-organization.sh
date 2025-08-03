#!/bin/bash

. ids-utils.sh
. network-utils.sh

ORG_DOMAIN=$1

# Check if organization domain is provided
if [ -z "$ORG_DOMAIN" ]; then
    echo "Usage: $0 <organization_domain>"
    exit 1
fi

# Verify the identity of the caller
verify_identity "$ORG_DOMAIN"

# Join the organization to the network
join_organization "$ORG_DOMAIN"