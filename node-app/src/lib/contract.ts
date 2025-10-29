import { Gateway, Contract } from '@hyperledger/fabric-gateway';
import { TextDecoder } from 'util';

import config from '../config/config';

const utf8Decoder = new TextDecoder();

export class ContractManager {
    private channel_name: string;
    private chaincode_name: string;
    private contract: Contract;

    constructor(gateway: Gateway) {
        this.channel_name = config.FABRIC_DEFAULT_CHANNEL || '';
        this.chaincode_name = config.FABRIC_DEFAULT_CC_NAME || '';

        if (!this.channel_name) {
            throw new Error('Channel name is not defined in environment variables.');
        }

        if (!this.chaincode_name) {
            throw new Error('Chaincode name is not defined in environment variables.');
        }
        
        // console.log(`[APP] Using channel: ${this.channel_name}`);
        // console.log(`[APP] Using chaincode: ${this.chaincode_name}`);
        this.contract = gateway.getNetwork(this.channel_name).getContract(this.chaincode_name);
    }

    public async createResource(args: (string | Uint8Array)[]): Promise<any> {    
        console.log(`[APP] Submit Transaction: CreateResource`);
        
        let result;
        try {
            result = await this.contract.submitTransaction('CreateResource', ...args );
        } catch (error) {
            throw error;
        }
        
        const resource = utf8Decoder.decode(result); 
        return JSON.parse(resource);
    }

    public async readResourcesByTimestamp(args: (string | Uint8Array)[]): Promise<any> {
        console.log(`[APP] Submit Transaction: ReadResourcesByTimestamp`);

        let result;
        try {
            result = await this.contract.evaluateTransaction('GetResourcesByTimestamp', ...args);
        } catch (error) {
            throw error;
        }

        const resource = utf8Decoder.decode(result);
        return JSON.parse(resource);
    }
}