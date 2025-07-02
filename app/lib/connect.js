require('dotenv').config();
const grpc = require('@grpc/grpc-js');
const { connect, signers, hash } = require('@hyperledger/fabric-gateway');
const crypto = require('node:crypto');
const fs = require('node:fs/promises');
const path = require('node:path');

class HLFConnector {
    constructor() {
        this.msp_id = process.env.MSP_ID || 'Org1';
        this.crypto_path = process.env.CRYPTO_PATH || path.resolve(
            __dirname,
            '..',
            '..',
            'runtime',
            'crypto-config',
            'peerOrganizations',
            'org1.testbed.local'
        );
        this.key_dir_path = process.env.KEY_DIR_PATH || path.resolve(
            this.crypto_path,
            'users',
            'User1@org1.testbed.local',
            'msp',
            'keystore'
        );
        this.cert_dir_path = process.env.CERT_DIR_PATH || path.resolve(
            this.crypto_path,
            'users',
            'User1@org1.testbed.local',
            'msp',
            'signcerts'
        );
        this.tls_cert_path = process.env.TLS_CERT_PATH || path.resolve(
            this.crypto_path,
            'peers',
            'peer0.org1.testbed.local',
            'tls',
            'ca.crt'
        );
        this.peer_endpoint = process.env.PEER_ENDPOINT || 'localhost:17051';
        this.peer_host_alias = process.env.PEER_HOST_ALIAS || 'peer0.org1.testbed.local';
    }

    async #newGrpcConnection() {
        const tls_root_cert = await fs.readFile(this.tls_cert_path);
        const tls_credentials = grpc.credentials.createSsl(tls_root_cert);
        return new grpc.Client(this.peer_endpoint, tls_credentials, {
            'grpc.ssl_target_name_override': this.peer_host_alias,
        });
    }

    async #newIdentity() {
        const cert_path = await this.#getFirstDirFileName(this.cert_dir_path);
        const credentials = await fs.readFile(cert_path);
        return { msp_id: this.msp_id, credentials };
    }

    async #newSigner() {
        const key_path = await this.#getFirstDirFileName(this.key_dir_path);
        const pkey_pem = await fs.readFile(key_path);
        const pkey = crypto.createPrivateKey(pkey_pem);
        return signers.newPrivateKeySigner(pkey);
    }

    async #getFirstDirFileName(dir_path) {
        const files = await fs.readdir(dir_path);
        const file = files[0];
        if (!file) {
            throw new Error(`No files in directory: ${dir_path}`);
        }
        return path.join(dir_path, file);
    }

    async connect() {
        const client = await this.#newGrpcConnection();
        const gateway = connect({
            client,
            identity: await this.#newIdentity(),
            signer: await this.#newSigner(),
            hash: hash.sha256,
            evaluateOptions: () => {
                return { deadline: Date.now() + 5000 };
            },
            endorseOptions: () => {
                return { deadline: Date.now() + 15000 };
            },
            submitOptions: () => {
                return { deadline: Date.now() + 5000 };
            },
            commitStatusOptions: () => {
                return { deadline: Date.now() + 60000 };
            },
        });

        console.log(`Gateway created for peer: ${this.peer_host_alias} at ${this.peer_endpoint}`);

        return gateway;
    }
}

module.exports = HLFConnector;