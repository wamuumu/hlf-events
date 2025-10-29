import express from 'express';
import path from 'path';
import router from './api/router';
import config from './config/config';

import { ConnectionManager } from './lib/connect';
import { EventManager } from './lib/listener';
import { ContractManager } from './lib/contract';

(async () => {
    const connection_manager: ConnectionManager = new ConnectionManager();

    connection_manager.onNewGateway(async (gateway) => {
        console.log(`[APP] Connection established with: ${gateway.getIdentity().mspId}`);

        const contract_manager: ContractManager = new ContractManager(gateway);
        const event_manager: EventManager = new EventManager(gateway);
        event_manager.listen();
        
        const app = express();
        app.use(express.json());
        app.use('/api', router);
        app.use(express.static(path.join(__dirname, 'public'))); // Serve static files from the 'public' directory
        app.set('contractManager', contract_manager);
        app.set('eventManager', event_manager);

        const server = app.listen(config.PORT, () => {
            console.log(`[APP] Server is running on port ${config.PORT} in ${config.NODE_ENV} mode`);
        }).on('error', (error) => {
            console.error('[APP] Server error:', error);
            process.exit(1);
        });

        const shutdown = (signal: string) => {
            console.log(`[APP] ${signal} signal received: closing HTTP server`);
            server.close(() => {
                console.log('[APP] HTTP server closed.');
            });
            event_manager?.stop();
            connection_manager?.closeGatewayConnection();
            process.exit(1);
        };

        process.on('SIGTERM', () => shutdown('SIGTERM'));
        process.on('SIGINT', () => shutdown('SIGINT'));
    });

    await connection_manager.createGatewayConnection();
})();