/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import * as grpc from '@grpc/grpc-js';
import {  Identity,  Signer, signers, connect, hash, Gateway } from '@hyperledger/fabric-gateway';
import * as crypto from 'crypto';
import * as fs from 'fs';
import * as path from 'path';


export interface PeerConfig {
    endpoint: string;
    hostname: string;
    port?: number;
}

export interface OrganizationConfig {
    mspId: string;
    name: string;
    domain: string;
    peers: PeerConfig[];
    users: string[];
}

export interface ConnectionProfile {
    organizations: OrganizationConfig[];
    connectionTimeout: number;
    retryAttempts: number;
    retryDelay: number;
    pathTemplates: {
        tlsCertPath: string;
        userKeyPath: string;
        userCertPath: string;
    };
}

export interface Connection {
    client: grpc.Client;
    gateway: Gateway;
    organization: OrganizationConfig;
    peer: PeerConfig;
    user: string;
}

export class ConnectionManager {
    private connection_profile: ConnectionProfile;
    private connection_details: Connection = {
        client: undefined as unknown as grpc.Client,
        gateway: undefined as unknown as Gateway,
        organization: undefined as unknown as OrganizationConfig,
        peer: undefined as unknown as PeerConfig,
        user: ''
    };

    constructor();
    constructor(organization?: string, peer?: string, user?: string);
    
    constructor(organization?: string, peer?: string, user?: string) {
        this.connection_profile = this.loadProfile(organization, peer, user);
    }

    public loadProfile(organization?: string, peer?: string, user?: string) : ConnectionProfile {
        const profile_path = path.resolve(__dirname, '..', 'config', 'connection-profile.json');
        console.log(`Loading connection profile from: ${profile_path}`);
        const profile_data = fs.readFileSync(profile_path, 'utf8');
        if (!profile_data)
            throw new Error(`Connection profile not found at path: ${profile_path}`);
        const profile_json = JSON.parse(profile_data);

        const org_name = organization || String(process.env.FABRIC_DEFAULT_ORGANIZATION) || profile_json.organizations[0]?.name;
        if (!org_name) {
            throw new Error('No organization specified and none found in connection profile or environment variable FABRIC_DEFAULT_ORG');
        }
        console.log(`Using organization: ${org_name}`);
        const org_json = profile_json.organizations.find((o: OrganizationConfig) =>
            o.name.toLowerCase() === org_name.toLowerCase());
        if (!org_json) {
            throw new Error(`Organization ${org_name} not found in connection profile`);
        }

        const user_name = user || String(process.env.FABRIC_DEFAULT_USER) || org_json.users[0];
        if (!user_name) {
            throw new Error('No user specified and none found in organization or environment variable FABRIC_DEFAULT_USER');
        }
        console.log(`Using user: ${user_name}`);
        user = org_json.users.find((u: string) =>
            u.toLowerCase() === user_name.toLowerCase());
        if (user) {
            user = user.charAt(0).toUpperCase() + user.slice(1); // Capitalize to match the expected format
        } else {
            throw new Error(`User ${user_name} not found in organization ${org_json.name}`);
        }

        const peer_name = peer || org_json.peers[0]?.hostname;
        if (!peer_name) {
            throw new Error('No peer specified and none found in organization');
        }
        console.log(`Using peer: ${peer_name}`);
        const peer_json = org_json.peers.find((p: PeerConfig) =>
            p.hostname.toLowerCase() === peer_name.toLowerCase());
        if (!peer_json) {
            throw new Error(`Peer ${peer_name} not found in organization ${org_json.name}`);
        }

        this.connection_details.organization = org_json;
        this.connection_details.peer = peer_json;
        this.connection_details.user = user;

        return this.resolvePaths(profile_json, org_json, peer_json, user);
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

    private resolvePaths(connection_profile: ConnectionProfile, organization: OrganizationConfig, peer: PeerConfig, user: string): ConnectionProfile {
        const resolvedProfile: ConnectionProfile = { ...connection_profile };
        const crypto_path = path.resolve(__dirname, '..', '..', 'network', 'organizations', 'peerOrganizations', organization.domain);
        resolvedProfile.pathTemplates = {
            userKeyPath: path.resolve(crypto_path, 'users', `${user}@${organization.domain}`, 'msp', 'keystore'),
            userCertPath: path.resolve(crypto_path, 'users', `${user}@${organization.domain}`, 'msp', 'signcerts'),
            tlsCertPath: path.resolve(crypto_path, 'peers', `${peer.hostname}`, 'tls', 'ca.crt')
        };
        return resolvedProfile;
    }

    private async createGrpcClient(): Promise<grpc.Client> {
        const tls_root_cert = await fs.promises.readFile(this.connection_profile.pathTemplates.tlsCertPath);
        const tls_credentials = grpc.credentials.createSsl(tls_root_cert);
        const organization = this.connection_details.organization;
        if (!organization) {
            throw new Error(`Organization is undefined`);
        }
        const peer = this.connection_details.peer;
        if (!peer) {
            throw new Error(`Peer is undefined for organization ${organization.name}`);
        }
        return new grpc.Client(peer.endpoint, tls_credentials, {
            'grpc.ssl_target_name_override': peer.hostname
        });
    }

    private async createIdentity(): Promise<Identity> {
        const certPath = await this.getFirstDirFileName(this.connection_profile.pathTemplates.userCertPath);
        const credentials = await fs.promises.readFile(certPath);
        const organization = this.connection_details.organization;
        if (!organization) {
            throw new Error(`Organization is undefined`);
        }
        return { 
            mspId: organization.mspId, 
            credentials: credentials 
        };
    }

    private async createSigner(): Promise<Signer> {
        const key_path = await this.getFirstDirFileName(this.connection_profile.pathTemplates.userKeyPath);
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
        const deadline = process.env.CONNECTION_RECONNECT_TIMEOUT ? parseInt(process.env.CONNECTION_RECONNECT_TIMEOUT) : 10000;
        try {
            channel.watchConnectivityState(current_state, Date.now() + deadline, async (error?: Error) => {
                if (error) {
                    this.monitorConnection(); // Here if client is still running in READY state
                } else {
                    current_state = channel.getConnectivityState(true);
                    console.log("Client state changed: ", current_state);

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