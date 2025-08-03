#!/bin/bash

. ids-utils.sh
. cc-utils.sh

ORG_DOMAIN=$1

# Check if the organization domain is provided
if [ -z "$ORG_DOMAIN" ]; then
    echo "Usage: $0 <org-domain>"
    exit 1
fi

# Verify the identity of the caller
verify_identity "$ORG_DOMAIN"

# Calculate the package ID for the chaincode (INFO only)
calculate_package_id

# Install the chaincode
install_chaincode "$ORG_DOMAIN"