/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import * as grpc from '@grpc/grpc-js';
import { ChaincodeEvent, CloseableAsyncIterable, connect, Contract, GatewayError, hash, Network } from '@hyperledger/fabric-gateway';
import { TextDecoder } from 'util';
import { newGrpcConnection, newIdentity, newSigner } from './connect';

const channel_name = 'mychannel';
const chaincode_name = 'cc-test';

const utf8Decoder = new TextDecoder();

async function main(): Promise<void> {
    const client = await newGrpcConnection();
    const gateway = connect({
        client,
        identity: await newIdentity(),
        signer: await newSigner(),
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

    let events: CloseableAsyncIterable<ChaincodeEvent> | undefined;

    // Set up graceful shutdown on Ctrl+C
    const cleanup = () => {
        console.log('\n*** [APP] Shutting down gracefully...');
        events?.close();
        gateway.close();
        client.close();
        process.exit(0);
    };

    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);

    try {
        const network = gateway.getNetwork(channel_name);
        const contract = network.getContract(chaincode_name);

        // Listen for events emitted by transactions
        events = await startEventListening(network);

        // Execute initial transaction
        const write_resource = await createResource(contract);

        // Read the resource to trigger an event
        const pid = write_resource.PID;
        await readResource(contract, pid);

        console.log('\n*** [APP] Event listener is running. Press Ctrl+C to stop.');
        console.log('*** [APP] Waiting for chaincode events from transactions...');

        // Keep the application running indefinitely
        await new Promise(() => {}); // This will never resolve, keeping the app alive

    } catch (error) {
        console.error('Error in main loop:', error);
        cleanup();
    }
}

main().catch((error: unknown) => {
    console.error('******** FAILED to run the application:', error);
    process.exitCode = 1;
});

async function startEventListening(network: Network): Promise<CloseableAsyncIterable<ChaincodeEvent>> {
    console.log('\n*** Start chaincode event listening');

    const events = await network.getChaincodeEvents(chaincode_name);
    
    void readEvents(events); // Don't await - run asynchronously
    return events;
}

async function readEvents(events: CloseableAsyncIterable<ChaincodeEvent>): Promise<void> {
    try {
        for await (const event of events) {
            const payload = parseJson(event.payload);
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

function parseJson(jsonBytes: Uint8Array): unknown {
    const json = utf8Decoder.decode(jsonBytes);
    return JSON.parse(json);
}

async function createResource(contract: Contract): Promise<any> {
    const now = Date.now();
    const pid = `PID_${String(now)}`;

    console.log(`\n--> [APP] Submit Transaction: CreateResource`);

    const result = await contract.submitAsync('CreateResource', {
        arguments: [
            pid,
            'https://example.com/resource',
            'hash_13134bh34bj32b4',
            'timestamp_432432423432',
            JSON.stringify(['owner1', 'owner2']),
        ],
    });

    const status = await result.getStatus();
    if (!status.successful) {
        throw new Error(`failed to commit transaction ${status.transactionId} with status code ${String(status.code)}`);
    }

    const resource = utf8Decoder.decode(result.getResult());
    return JSON.parse(resource);
}

async function readResource(contract: Contract, pid: string): Promise<any> {
    console.log(`\n--> [APP] Submit Transaction: ReadResource, PID: ${pid}`);

    const result = await contract.submitAsync('ReadResource', {
        arguments: [pid],
    });

    const status = await result.getStatus();
    if (!status.successful) {
        throw new Error(`failed to commit transaction ${status.transactionId} with status code ${String(status.code)}`);
    }

    const resource = utf8Decoder.decode(result.getResult());
    return JSON.parse(resource);
}
