/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import * as grpc from '@grpc/grpc-js';
import {  Identity,  Signer, signers } from '@hyperledger/fabric-gateway';
import * as crypto from 'crypto';
import { promises as fs } from 'fs';
import * as path from 'path';

const msp_id = 'Org1MSP';

// Path to crypto materials.
const crypto_path = path.resolve(
    __dirname, 
    '..', 
    '..', 
    'network', 
    'organizations', 
    'peerOrganizations', 
    'org1.testbed.local'
);

// Path to user private key directory.
const key_dir_path = path.resolve(
    crypto_path, 
    'users', 
    'User1@org1.testbed.local', 
    'msp', 
    'keystore'
);

// Path to user certificate.
const cert_dir_path = path.resolve(
    crypto_path, 
    'users', 
    'User1@org1.testbed.local', 
    'msp', 
    'signcerts'
);

// Path to peer tls certificate.
const tls_cert_path = path.resolve(
    crypto_path, 
    'peers', 
    'peer0.org1.testbed.local', 
    'tls', 
    'ca.crt'
);

// Gateway peer endpoint and hostname.
const peer_endpoint = 'localhost:7051';
const peer_hostname = 'peer0.org1.testbed.local';

export async function newGrpcConnection(): Promise<grpc.Client> {
    const tls_root_cert = await fs.readFile(tls_cert_path);
    const tls_credentials = grpc.credentials.createSsl(tls_root_cert);
    return new grpc.Client(peer_endpoint, tls_credentials, {
        'grpc.ssl_target_name_override': peer_hostname,
    });
}

export async function newIdentity(): Promise<Identity> {
    const certPath = await getFirstDirFileName(cert_dir_path);
    const credentials = await fs.readFile(certPath);
    return { 
        mspId: msp_id, 
        credentials: credentials 
    };
}

export async function newSigner(): Promise<Signer> {
    const key_path = await getFirstDirFileName(key_dir_path);
    const pkey_pem = await fs.readFile(key_path);
    const pkey = crypto.createPrivateKey(pkey_pem);
    return signers.newPrivateKeySigner(pkey);
}

async function getFirstDirFileName(dir_path: string): Promise<string> {
    const files = await fs.readdir(dir_path);
    const file = files[0];
    if (!file) {
        throw new Error(`No files in directory: ${dir_path}`);
    }
    return path.join(dir_path, file);
}
