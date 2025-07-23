#!/bin/bash

# Load network configuration variables
. ../network.config

# Utility: pull & convert to sandbox folder if missing
pull_if_missing() {
    local name=$1 tag=$2 
    local sandbox="sandboxes/${name}"
    local tarball="sandboxes/${name}.tar"

    if ! [[ -d "sandboxes" ]]; then
        mkdir -p sandboxes
    fi

    if [[ -d "$sandbox" ]]; then
        echo "$sandbox already exists, skipping."
        return
    fi

    # 1. Pull the Docker image if not present
    docker pull hyperledger/${name}:${tag}

    # 2. Save it to a tarball
    docker save hyperledger/${name}:${tag} -o ${tarball}

    # 3. Convert the tarball to a sandbox folder
    # Note: --sandbox is used to create a writable directory structure, which enables older Singularity versions to run
    singularity build --sandbox ${sandbox} docker-archive://${tarball}

    # 4. Clean up the tarball
    rm -f "${tarball}"

    echo "Created sandbox at ${sandbox}"
}

# Helpers to create and start an orderer instance
create_orderer_instance() {

    local instance_name=$1

    local binddir=data/${instance_name}
    mkdir -p ${binddir}

    singularity instance start \
        --bind ../organizations/ordererOrganizations/ord.testbed.local/orderers/${instance_name}.ord.testbed.local/msp:/var/hyperledger/orderer/msp:ro \
        --bind ../organizations/ordererOrganizations/ord.testbed.local/orderers/${instance_name}.ord.testbed.local/tls:/var/hyperledger/orderer/tls:ro \
        --bind ${binddir}:/var/hyperledger/production/orderer \
        sandboxes/fabric-orderer ${instance_name}
}

start_orderer_instance() {
    
    local instance_name=$1
    local endpoint=$2
    local listen_port=$3
    local admin_port=$4
    local ops_port=$5

    echo "Starting ${instance_name} on ${endpoint}:${listen_port}..."
    export SINGULARITYENV_ORDERER_GENERAL_LISTENADDRESS=${endpoint}
    export SINGULARITYENV_ORDERER_GENERAL_LISTENPORT=${listen_port}
    export SINGULARITYENV_ORDERER_GENERAL_LOCALMSPID=OrdererMSP
    export SINGULARITYENV_ORDERER_GENERAL_LOCALMSPDIR=/var/hyperledger/orderer/msp

    export SINGULARITYENV_ORDERER_GENERAL_TLS_ENABLED=true
    export SINGULARITYENV_ORDERER_GENERAL_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
    export SINGULARITYENV_ORDERER_GENERAL_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
    export SINGULARITYENV_ORDERER_GENERAL_TLS_ROOTCAS='[/var/hyperledger/orderer/tls/ca.crt]'

    export SINGULARITYENV_ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/var/hyperledger/orderer/tls/server.crt
    export SINGULARITYENV_ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/var/hyperledger/orderer/tls/server.key
    export SINGULARITYENV_ORDERER_GENERAL_CLUSTER_ROOTCAS='[/var/hyperledger/orderer/tls/ca.crt]'

    export SINGULARITYENV_ORDERER_GENERAL_BOOTSTRAPMETHOD=none
    export SINGULARITYENV_ORDERER_CHANNELPARTICIPATION_ENABLED=true

    export SINGULARITYENV_ORDERER_ADMIN_TLS_ENABLED=true
    export SINGULARITYENV_ORDERER_ADMIN_TLS_CERTIFICATE=/var/hyperledger/orderer/tls/server.crt
    export SINGULARITYENV_ORDERER_ADMIN_TLS_PRIVATEKEY=/var/hyperledger/orderer/tls/server.key
    export SINGULARITYENV_ORDERER_ADMIN_TLS_ROOTCAS='[/var/hyperledger/orderer/tls/ca.crt]'
    export SINGULARITYENV_ORDERER_ADMIN_TLS_CLIENTROOTCAS='[/var/hyperledger/orderer/tls/ca.crt]'
    export SINGULARITYENV_ORDERER_ADMIN_LISTENADDRESS=${endpoint}:${admin_port}

    export SINGULARITYENV_ORDERER_OPERATIONS_LISTENADDRESS=${endpoint}:${ops_port}
    export SINGULARITYENV_ORDERER_METRICS_PROVIDER=prometheus

    singularity exec instance://${instance_name} orderer > logs/${instance_name}.log 2>&1 &
}

# Helpers to create and start a peer instance
create_peer_instance() {
    
    local peer_name=$1
    local org=$2

    local binddir=data/${peer_name}.${org}
    mkdir -p ${binddir}
    
    singularity instance start \
        --bind ../organizations/peerOrganizations/${org}.testbed.local/peers/${peer_name}.${org}.testbed.local:/etc/hyperledger/fabric:ro \
        --bind ../config/core.yaml:/etc/hyperledger/fabric/core.yaml:ro \
        --bind ${binddir}:/var/hyperledger/production \
        sandboxes/fabric-peer ${peer_name}.${org}
}

start_peer_instance() {
    local peer_name=$1
    local org=$2
    local endpoint=$3
    local peer_address=$4
    local cc_address=$5
    local ops_port=$6

    echo "Starting ${peer_name}.${org}..."
    export SINGULARITYENV_FABRIC_CFG_PATH=/etc/hyperledger/fabric
    export SINGULARITYENV_FABRIC_LOGGING_SPEC=INFO
    export SINGULARITYENV_CORE_PEER_TLS_ENABLED=true
    export SINGULARITYENV_CORE_PEER_ID=${peer_name}.${org}.testbed.local
    export SINGULARITYENV_CORE_PEER_ADDRESS=${peer_name}.${org}.testbed.local:${peer_address}
    export SINGULARITYENV_CORE_PEER_LISTENADDRESS=${endpoint}:${peer_address}
    export SINGULARITYENV_CORE_PEER_CHAINCODEADDRESS=${peer_name}.${org}.testbed.local:${cc_address}
    export SINGULARITYENV_CORE_PEER_CHAINCODELISTENADDRESS=${endpoint}:${cc_address}
    export SINGULARITYENV_CORE_PEER_GOSSIP_BOOTSTRAP=${peer_name}.${org}.testbed.local:${peer_address}
    export SINGULARITYENV_CORE_PEER_GOSSIP_EXTERNALENDPOINT=${peer_name}.${org}.testbed.local:${peer_address}
    export SINGULARITYENV_CORE_PEER_LOCALMSPID=${org^}MSP
    export SINGULARITYENV_CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/fabric/msp
    export SINGULARITYENV_CORE_OPERATIONS_LISTENADDRESS=${endpoint}:${ops_port}
    export SINGULARITYENV_CORE_METRICS_PROVIDER=prometheus
    
    singularity exec instance://${peer_name}.${org} peer node start > logs/${peer_name}.${org}.log 2>&1 &
}

main() {

    echo "Using Fabric version: ${FABRIC_VERSION}"

    # Pull required images if not already present
    pull_if_missing fabric-orderer "$FABRIC_VERSION"
    pull_if_missing fabric-peer    "$FABRIC_VERSION"

    # Prepare data and logs dirs
    rm -rf data && mkdir -p data
    rm -rf logs && mkdir -p logs

    # Stop any existing instances
    singularity instance stop --all 2>/dev/null || true

    # Create orderer instances
    create_orderer_instance orderer1
    create_orderer_instance orderer2

    # Start orderers
    sudo fuser -k 7050/tcp 7053/tcp 9443/tcp 8050/tcp 8053/tcp 9444/tcp 2>/dev/null || true #TODO: remove this
    start_orderer_instance orderer1 0.0.0.0 7050 7053 9443
    start_orderer_instance orderer2 0.0.0.0 8050 8053 9444

    # Create peer instances
    create_peer_instance peer0 org1
    create_peer_instance peer0 org2
    create_peer_instance peer0 org3

    # Start peers
    sudo fuser -k 7051/tcp 7052/tcp 9445/tcp 8051/tcp 8052/tcp 9446/tcp 9051/tcp 9052/tcp 9447/tcp 2>/dev/null || true #TODO: remove this
    start_peer_instance peer0 org1 0.0.0.0 7051 7052 9445
    start_peer_instance peer0 org2 0.0.0.0 8051 8052 9446
    start_peer_instance peer0 org3 0.0.0.0 9051 9052 9447

    echo
    echo "All containers started successfully!"
    echo " • List: singularity instance list"
    echo " • Stop: singularity instance stop --all"
}

main
