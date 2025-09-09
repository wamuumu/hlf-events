#!/bin/bash

. ../network.config

# Extract major version number from FABRIC_VERSION
export FABRIC_MAJOR_VERSION=$(echo $FABRIC_VERSION | cut -d. -f1,2)

BENCHMARK_FILE=$1

if [ -z "$BENCHMARK_FILE" ]; then
    echo "Please provide a benchmark file."
    exit 1
fi

if [ ! -f "$BENCHMARK_FILE" ]; then
    echo "Benchmark file '$BENCHMARK_FILE' does not exist."
    exit 1
fi

BENCHMARK_NAME=$(basename "$BENCHMARK_FILE" .yaml)
BENCHMARK_DATE=$(date +"%Y-%m-%d_%H-%M-%S")

npx caliper launch manager \
    --caliper-flow-only-test \
    --caliper-fabric-gateway-enabled \
    --caliper-workspace ./ \
    --caliper-bind-cwd ./ \
    --caliper-sut "fabric@$FABRIC_MAJOR_VERSION" \
    --caliper-bind-sut "fabric:$FABRIC_MAJOR_VERSION" \
    --caliper-networkconfig networks/network-config-minimal.yaml \
    --caliper-benchconfig $BENCHMARK_FILE \
    --caliper-report-path ./results/${BENCHMARK_NAME}_report_${BENCHMARK_DATE}.html
