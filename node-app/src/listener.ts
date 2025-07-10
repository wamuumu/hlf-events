/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import * as grpc from '@grpc/grpc-js';
import { Gateway, GatewayError, Network, ChaincodeEvent, CloseableAsyncIterable } from '@hyperledger/fabric-gateway';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { TextDecoder } from 'util';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const utf8Decoder = new TextDecoder();

export class EventManager {
    private gateway: Gateway;
    private channel_name: string;
    private chaincode_name: string;
    private events: CloseableAsyncIterable<ChaincodeEvent> | undefined;

    constructor(gateway: Gateway) {
        this.gateway = gateway;
        this.channel_name = process.env.FABRIC_DEFAULT_CHANNEL || '';
        this.chaincode_name = process.env.FABRIC_DEFAULT_CC_NAME || '';
    }

    public async listen(): Promise<void> {
        try {
            if (!this.channel_name)
                throw new Error('Channel name is not defined in environment variables.');
            
            if (!this.chaincode_name)
                throw new Error('Chaincode name is not defined in environment variables.');

            const network = this.gateway.getNetwork(this.channel_name);
            
            this.events = await this.startEventListening(network);
        } catch (error: unknown) {
            console.error('Error starting event listener:', error);
        }
    }

    public async stop(): Promise<void> {
        if (this.events)
            await this.events.close();
    }

    private async startEventListening(network: Network): Promise<CloseableAsyncIterable<ChaincodeEvent>> {
        console.log('\n*** Start chaincode event listening');
    
        const events = await network.getChaincodeEvents(this.chaincode_name);
        
        void this.readEvents(events); // Don't await - run asynchronously
        return events;
    }
    
    private async readEvents(events: CloseableAsyncIterable<ChaincodeEvent>): Promise<void> {
        try {
            for await (const event of events) {
                const payload = this.parseJson(event.payload);
                console.log(`\n<-- [CHAINCODE] Chaincode event received: ${event.eventName} -`, payload);
            }
        } catch (error: unknown) {
            // Ignore the read error when events.close() is called explicitly
            if (!(error instanceof GatewayError) || error.code !== grpc.status.CANCELLED.valueOf()) {
                console.error('Error reading events:', error);
            }
        }
        console.log('*** Event listening stopped');
    }
    
    private parseJson(jsonBytes: Uint8Array): unknown {
        const json = utf8Decoder.decode(jsonBytes);
        return JSON.parse(json);
    }
}