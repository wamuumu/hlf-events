/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { Gateway, Network, ChaincodeEvent, CloseableAsyncIterable } from '@hyperledger/fabric-gateway';
import { TextDecoder } from 'util';

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
            
            await this.startEventListening(network);
        } catch (error: unknown) {
            console.error('Error starting event listener:', error);
        }
    }

    public stop(): void {
        if (this.events)
            this.events.close();
        console.log('*** Event listening stopped');
    }

    private async startEventListening(network: Network): Promise<void> {
        console.log('\n*** Start chaincode event listening');
    
        this.events = await network.getChaincodeEvents(this.chaincode_name);
        
        void this.readEvents(); // Don't await - run asynchronously
    }
    
    private async readEvents(): Promise<void> {
        if (this.events) {
            try {
                for await (const event of this.events) {
                    const payload = this.parseJson(event.payload);
                    console.log(`\n<-- [CHAINCODE] Chaincode event received: ${event.eventName} -`, payload);
                }
            } catch (error: unknown) {
                this.stop();
            }
        } else {
            console.error('No events to read. Ensure the event listener is started.');
        }
    }
    
    private parseJson(jsonBytes: Uint8Array): any {
        const json = utf8Decoder.decode(jsonBytes);
        return JSON.parse(json);
    }
}