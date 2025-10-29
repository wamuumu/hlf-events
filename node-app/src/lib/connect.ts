import * as grpc from '@grpc/grpc-js';
import {  Identity,  Signer, signers, connect, hash, Gateway } from '@hyperledger/fabric-gateway';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';

import config from '../config/config';

export interface PeerConfig {
    endpoint: string;
    hostname: string;
}

export interface OrganizationConfig {
    mspId: string;
    name: string;
    domain: string;
}

export interface ConnectionProfile {
    organization: OrganizationConfig;
    peer: PeerConfig;
    user: string;
    credentials: {
        tlsCertPath: string;
        userKeyPath: string;
        userCertPath: string;
    };
}

export interface Connection {
    client: grpc.Client;
    gateway: Gateway;
    profile: ConnectionProfile;
}

export class ConnectionManager {
    private connection_profile: ConnectionProfile;
    private connection_details: Connection;

    constructor() {
        let organization = {
            mspId: config.FABRIC_DEFAULT_MSPID,
            name: config.FABRIC_DEFAULT_ORGANIZATION,
            domain: config.FABRIC_DEFAULT_DOMAIN
        } as OrganizationConfig;

        let peer = {
            endpoint: config.FABRIC_DEFAULT_PEER_ENDPOINT,
            hostname: config.FABRIC_DEFAULT_PEER_HOSTNAME
        } as PeerConfig;

        this.connection_profile = this.resolvePaths(organization, peer, config.FABRIC_DEFAULT_USER);

        this.connection_details = {
            client: undefined as unknown as grpc.Client,
            gateway: undefined as unknown as Gateway,
            profile: this.connection_profile
        };
    }

    public async createGatewayConnection(): Promise<void> {
        try {
            this.connection_details.client = await this.createGrpcClient();
            this.connection_details.gateway = connect({
                client: this.connection_details.client,
                identity: await this.createIdentity(),
                signer: await this.createSigner(),
                hash: hash.sha256,
                evaluateOptions: () => {
                    return { deadline: Date.now() + 5000 }; // 5 seconds
                },
                endorseOptions: () => {
                    return { deadline: Date.now() + 15000 }; // 15 seconds
                },
                submitOptions: () => {
                    return { deadline: Date.now() + 5000 }; // 5 seconds
                },
                commitStatusOptions: () => {
                    return { deadline: Date.now() + 60000 }; // 1 minute
                },
            });

            await this.executeWhenReady(() => {
                if (!!this.connection_details.gateway && !!this._onNewGatewayCallback) {
                    this._onNewGatewayCallback(this.connection_details.gateway);
                    this.monitorConnection();
                }
            });
        } catch (error: unknown) {
            console.error('Error creating gateway connection:', error);
        }
    }

    private async executeWhenReady(callback: () => void): Promise<void> {
        return new Promise<void>((resolve, reject) => {
            this.connection_details.client.waitForReady(Date.now() + 500, (error?: Error) => {
                if (error) { 
                    // Client is not ready, retry
                    this.executeWhenReady(callback).then(resolve).catch(reject);
                } else {
                    callback();
                    resolve();
                }
            });
        });
    }

    public closeGatewayConnection(): void {
        if (this.connection_details.gateway)
            this.connection_details.gateway.close();
        if (this.connection_details.client)
            this.connection_details.client.close();

        this.connection_details.client = undefined as unknown as grpc.Client;
        this.connection_details.gateway = undefined as unknown as Gateway;
    }

    private resolvePaths(organization: OrganizationConfig, peer: PeerConfig, user: string): ConnectionProfile {
        const crypto_path = path.resolve(config.CRYPTO_PATH, 'peerOrganizations', organization.domain);
        return {
            organization,
            peer,
            user,
            credentials: {
                userKeyPath: path.resolve(crypto_path, 'users', `${user}@${organization.domain}`, 'msp', 'keystore'),
                userCertPath: path.resolve(crypto_path, 'users', `${user}@${organization.domain}`, 'msp', 'signcerts'),
                tlsCertPath: path.resolve(crypto_path, 'peers', `${peer.hostname}`, 'tls', 'ca.crt')
            }
        };
    }

    private async createGrpcClient(): Promise<grpc.Client> {
        const tls_root_cert = await fs.promises.readFile(this.connection_profile.credentials.tlsCertPath);
        const tls_credentials = grpc.credentials.createSsl(tls_root_cert);
        const organization = this.connection_profile.organization;
        if (!organization) {
            throw new Error(`Organization is undefined`);
        }
        const peer = this.connection_profile.peer;
        if (!peer) {
            throw new Error(`Peer is undefined for organization ${organization.name}`);
        }
        return new grpc.Client(peer.endpoint, tls_credentials, {
            'grpc.ssl_target_name_override': peer.hostname
        });
    }

    private async createIdentity(): Promise<Identity> {
        const certPath = await this.getFirstDirFileName(this.connection_profile.credentials.userCertPath);
        const credentials = await fs.promises.readFile(certPath);
        const organization = this.connection_profile.organization;
        if (!organization) {
            throw new Error(`Organization is undefined`);
        }
        return { 
            mspId: organization.mspId, 
            credentials: credentials 
        };
    }

    private async createSigner(): Promise<Signer> {
        const key_path = await this.getFirstDirFileName(this.connection_profile.credentials.userKeyPath);
        const pkey_pem = await fs.promises.readFile(key_path);
        const pkey = crypto.createPrivateKey(pkey_pem);
        return signers.newPrivateKeySigner(pkey);
    }

    private async getFirstDirFileName(dir_path: string): Promise<string> {
        const files = await fs.promises.readdir(dir_path);
        const file = files[0];
        if (!file) {
            throw new Error(`No files in directory: ${dir_path}`);
        }
        return path.join(dir_path, file);
    }

    private monitorConnection(): void {
        const channel = this.connection_details.client.getChannel();
        let current_state = channel.getConnectivityState(false);
        const deadline = config.CONNECTION_RECONNECT_TIMEOUT;
        try {
            channel.watchConnectivityState(current_state, Date.now() + deadline, async (error?: Error) => {
                if (error) {
                    this.monitorConnection(); // Here if client is still running in READY state
                } else {
                    current_state = channel.getConnectivityState(true);
                    console.log(
                        '[APP] Client state changed:',
                        (grpc.connectivityState as any)[current_state] ?? current_state
                    );

                    // TODO: If state becomes IDLE from READY, we can assume a disconnect
                }
            });
        } catch (error) {
            channel.close();
        }
    }

    private _onNewGatewayCallback?: (gateway: Gateway) => void;

    public onNewGateway(callback: (gateway: Gateway) => Promise<void>): void {
        this._onNewGatewayCallback = callback;
    }
}