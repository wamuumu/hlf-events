/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { Gateway, Contract } from '@hyperledger/fabric-gateway';
import * as path from 'path';
import * as dotenv from 'dotenv';
import { TextDecoder } from 'util';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

const utf8Decoder = new TextDecoder();

export class ContractManager {
    private channel_name: string;
    private chaincode_name: string;
    private contract: Contract;

    constructor(gateway: Gateway) {
        this.channel_name = process.env.FABRIC_DEFAULT_CHANNEL || '';
        this.chaincode_name = process.env.FABRIC_DEFAULT_CC_NAME || '';

        if (!this.channel_name) {
            throw new Error('Channel name is not defined in environment variables.');
        }

        if (!this.chaincode_name) {
            throw new Error('Chaincode name is not defined in environment variables.');
        }
        
        console.log(`\n*** [APP] Using channel: ${this.channel_name}`);
        console.log(`*** [APP] Using chaincode: ${this.chaincode_name}`);
        this.contract = gateway.getNetwork(this.channel_name).getContract(this.chaincode_name);
    }

    public async createResource(args: (string | Uint8Array)[]): Promise<any> {    
        console.log(`\n--> [APP] Submit Transaction: CreateResource`);
    
        const result = await this.contract.submitAsync('CreateResource', {
            arguments: args,
        });
    
        const status = await result.getStatus();
        if (!status.successful) {
            throw new Error(`failed to commit transaction ${status.transactionId} with status code ${String(status.code)}`);
        }
    
        const resource = utf8Decoder.decode(result.getResult());
        return JSON.parse(resource);
    }

    public async readResource(args: (string | Uint8Array)[]): Promise<any> {
        console.log(`\n--> [APP] Submit Transaction: ReadResource`);
    
        const result = await this.contract.submitAsync('ReadResource', {
            arguments: args,
        });
    
        const status = await result.getStatus();
        if (!status.successful) {
            throw new Error(`failed to commit transaction ${status.transactionId} with status code ${String(status.code)}`);
        }
    
        const resource = utf8Decoder.decode(result.getResult());
        return JSON.parse(resource);
    }
}