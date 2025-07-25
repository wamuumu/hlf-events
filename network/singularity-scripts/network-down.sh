#!/bin/bash

. network-utils.sh

# Parse command line arguments
FORCE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Stop any existing instances 
# TODO: is this safe? Should be removed?
singularity instance stop --all 2>/dev/null || true
rm -rf ~/.singularity/instances/* # Clean up orphan instances if any

# Delete data and logs directories
delete_folders $FORCE

