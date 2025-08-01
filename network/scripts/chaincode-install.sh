#!/bin/bash

. cc-utils.sh

# Calculate the package ID for the chaincode (INFO only)
calculate_package_id

# Install the chaincode
install_chaincode