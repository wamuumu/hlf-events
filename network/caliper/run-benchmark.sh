#!/bin/bash

. ../network.config

# Extract major version number from FABRIC_VERSION
export FABRIC_MAJOR_VERSION=$(echo $FABRIC_VERSION | cut -d. -f1,2)

if [ -z "$1" ]; then
    echo "Please provide a benchmark file."
    exit 1
fi

BENCHMARK_FILE=$1
BENCHMARK_NAME=$(basename "$BENCHMARK_FILE" .yaml)
mkdir -p results/$BENCHMARK_NAME

CONTAINER_ID=$(docker compose -f docker-compose-caliper.yaml run caliper \
    launch manager \
    --caliper-networkconfig networks/network-config-minimal.yaml \
    --caliper-benchconfig $BENCHMARK_FILE)

docker wait $CONTAINER_ID
docker cp $CONTAINER_ID:/hyperledger/caliper/report.html results/$BENCHMARK_NAME/report.html
docker rm $CONTAINER_ID
