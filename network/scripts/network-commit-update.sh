#!/bin/bash

. network-utils.sh

UPDATE_TRANSACTION_FILE=$1
ORG_DOMAIN=$2

# Check if the update transaction file is provided
if [ -z "${UPDATE_TRANSACTION_FILE}" ]; then
    echo "Usage: $0 <update-transaction-file>"
    exit 1
fi

# Check if the update transaction file exists
if [ ! -f "${UPDATE_TRANSACTION_FILE}" ]; then
    echo "Update transaction file not found: ${UPDATE_TRANSACTION_FILE}"
    exit 1
fi

# Check if the organization domain is set
if [ -z "${ORG_DOMAIN}" ]; then
    echo "Error: Organization domain is not specified."
    exit 1
fi

# Commit the update transaction to the channel
commit_update_transaction ${UPDATE_TRANSACTION_FILE} ${ORG_DOMAIN}