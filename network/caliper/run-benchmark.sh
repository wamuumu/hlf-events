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

# Run the benchmark in a detached container
CONTAINER_ID=$(docker compose -f docker-compose-caliper.yaml run -d caliper \
    launch manager \
    --caliper-networkconfig networks/network-config-minimal.yaml \
    --caliper-benchconfig $BENCHMARK_FILE)

if [ -z "$CONTAINER_ID" ]; then
    echo "Failed to start the benchmark container."
    exit 1
fi

# Stream all the logs to the console
docker logs -f $CONTAINER_ID &

# Wait for the benchmark to complete
docker wait $CONTAINER_ID

# Retrieve the report from the container before removing it
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
docker cp $CONTAINER_ID:/hyperledger/caliper/report.html results/$BENCHMARK_NAME/report_$DATE.html
docker rm $CONTAINER_ID
