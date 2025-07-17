#!/bin/bash

. ../network.config

export PATH=${PATH}:${FABRIC_BIN_PATH}
export FABRIC_CFG_PATH=${FABRIC_CFG_PATH}

#User has not provided a name
if [ -z "${CC_NAME}" ]; then
    echo "No chaincode name was provided."
    exit 1

# User has not provided a path
elif [ -z "${CC_PATH}" ]; then
    echo "No chaincode path was provided."
    exit 1

# User has not provided a language
elif [ -z "${CC_RUNTIME_LANGUAGE}" ]; then
    echo "No chaincode language was provided."
    exit 1
fi

if [ -d ${NETWORK_PACKAGE_PATH} ]; then
    rm -rf ${NETWORK_PACKAGE_PATH}
fi

mkdir -p ${NETWORK_PACKAGE_PATH}

echo ${CC_NAME}
echo ${CC_PATH}
echo ${CC_RUNTIME_LANGUAGE}
echo ${CC_VERSION}

which peer > /dev/null
if [ $? -ne 0 ]; then
    echo "Peer CLI tool not found in PATH. Please install Hyperledger Fabric binaries."
    exit 1
else
    echo "Peer CLI tool found at: $(which peer)"
    peer lifecycle chaincode package ${NETWORK_PACKAGE_PATH}/${CC_NAME}_${CC_VERSION}.tar.gz --path ${CC_PATH} --lang ${CC_RUNTIME_LANGUAGE} --label ${CC_NAME}_${CC_VERSION}
    echo "Chaincode packaged successfully at ${NETWORK_PACKAGE_PATH}/${CC_NAME}_${CC_VERSION}.tar.gz"
fi