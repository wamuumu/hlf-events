#!/bin/bash

./docker-down.sh
./docker-up.sh
./join-network.sh
./deploy-chaincode.sh
./join-organization.sh org4/crypto-config.yaml org4/configtx.yaml org4/docker-compose.yaml
sleep 5
./leave-organization.sh 4
./docker-down.sh