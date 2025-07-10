/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import { ConnectionManager } from './connect';
import { EventManager } from './listener';
import { ContractManager } from './contract';

async function main(): Promise<void> {

    const connection_manager = new ConnectionManager();
    const gateway = await connection_manager.createGatewayConnection();
    
    // const connection_details = connection_manager.getConnectionDetails();

    // const conn_state = connection_details.client.getChannel().getConnectivityState(false);
    // console.log(`\n*** [APP] Channel connectivity state: ${conn_state}`);

    // TODO: Watch for connectivity state changes. If the connection drops, create a new connection with another peer.

    const event_manager = new EventManager(gateway);
    await event_manager.listen();

    const contract_manager = new ContractManager(gateway);

    const resource = [
        `pid_test_${Date.now()}`,
        'uri_test',
        'hash_test',
        'timestamp_test',
        JSON.stringify(['owner1', 'owner2']),
    ]

    const created = await contract_manager.createResource(resource);
    const retrieved = await contract_manager.readResource([created.PID]);

    console.log(created.PID, retrieved.PID);

    // Set up graceful shutdown on Ctrl+C
    const cleanup = () => {
        console.log('\n*** [APP] Shutting down gracefully...');
        event_manager.stop();
        connection_manager.closeGatewayConnection();
        process.exit(0);
    };

    process.on('SIGINT', cleanup);
    process.on('SIGTERM', cleanup);

    await new Promise(() => {}); // Keep the process running to listen for events
}

main();
