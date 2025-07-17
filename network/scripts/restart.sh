#!/bin/bash

./docker-down.sh
./docker-up.sh
./join-network.sh
./join-organization.sh 4 org4/crypto-config.yaml org4/configtx.yaml org4/docker-compose.yaml