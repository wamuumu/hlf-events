/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import * as path from 'path';
import * as dotenv from 'dotenv';

dotenv.config({ path: path.resolve(__dirname, '../.env') });

import { ConnectionManager } from './connect';
import { EventManager } from './listener';
import { ContractManager } from './contract';

async function main(): Promise<void> {

    const connection_manager = new ConnectionManager();
    let event_manager: EventManager | undefined;
    let contract_manager: ContractManager | undefined;

    connection_manager.onNewGateway(async (gateway) => {
        console.log(`\n*** [APP] New gateway connection established: ${gateway.getIdentity().mspId}`);

        event_manager = new EventManager(gateway);
        event_manager.listen();

        contract_manager = new ContractManager(gateway);
    });

    await connection_manager.createGatewayConnection();
    
    console.log('\n*** [APP] Gateway connection established. Listening for events...');
    if (contract_manager) {

        const resource = [
            `pid_test_${Date.now()}`,
            'uri_test',
            'hash_test',
            'timestamp_test',
            JSON.stringify(['owner1', 'owner2']),
        ]

        try {
            const created = await contract_manager.createResource(resource);
            const retrieved = await contract_manager.readResource([created.PID]);

            console.log(created.PID, retrieved.PID);
        } catch (error) {
            console.error('Error during resource creation or retrieval:', error);
        }
    }
    
    // Set up graceful shutdown on Ctrl+C
    const cleanup = () => {
        console.log('\n*** [APP] Shutting down gracefully...');
        event_manager?.stop();
        connection_manager.closeGatewayConnection();
        process.exit(0);
    };

    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);

    await new Promise(() => {}); // Keep the process running to listen for events
}

main();
