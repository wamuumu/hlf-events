#!/bin/bash

. network-utils.sh

ORD_ID=$1

# Check if orderer ID is provided
if [ -z "$ORD_ID" ]; then
    echo "Usage: $0 <orderer_id>"
    exit 1
fi

# Join the orderer to the network
join_orderer ${ORD_ID}