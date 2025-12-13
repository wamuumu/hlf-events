import { Request, Response } from 'express';

export const createResource = async (req: Request, res: Response) => {

    const contract_manager = req.app.get('contractManager');
    
    // Implementation for creating a resource
    if (!contract_manager) {
        return res.status(500).json({ error: 'Contract manager not initialized' });
    }

    const { pid, uri, hash, timestamp, owners } = req.body;

    if (!pid || !uri || !hash || !timestamp || !owners) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    const resource = [
        pid,
        uri,
        hash,
        timestamp.toString(),
        JSON.stringify(owners)
    ]

    try {
        await contract_manager.createResource(resource);
        return res.status(201).json({ pid, uri, hash, timestamp, owners });
    } catch (error) {
        console.error('Error during resource creation:', error);
        return res.status(500).json({ error: 'Failed to create resource' });
    }
};

export const readResourcesByTimestamp = async (req: Request, res: Response) => {
    
    const contract_manager = req.app.get('contractManager');

    // Implementation for reading a resource by timestamp
    if (!contract_manager) {
        return res.status(500).json({ error: 'Contract manager not initialized' });
    }

    const { start, end } = req.query as { start?: string; end?: string };

    if (!start || !end) {
        return res.status(400).json({ error: 'Start and end timestamp parameters are required' });
    }

    try {
        const resources = await contract_manager.readResourcesByTimestamp([start, end]);
        console.log('Retrieved resources by timestamp:', resources);
        return res.status(200).json(resources);
    } catch (error) {
        console.error('Error during resource retrieval by timestamp:', error);
        return res.status(500).json({ error: 'Failed to retrieve resources by timestamp' });
    }
};

export const getEventStream = (req: Request, res: Response) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.flushHeaders();

    const eventManager = req.app.get('eventManager');

    if (!eventManager) {
        res.write('data: {"error": "Event manager not available"}\n\n');
        res.end();
        return;
    }

    // Send initial connection message
    res.write('data: {"type": "connected"}\n\n');

    // Register this client to receive events
    const eventListener = (event: any) => {
        res.write(`data: ${JSON.stringify(event)}\n\n`);
    };

    eventManager.addListener(eventListener);

    // Clean up on client disconnect
    req.on('close', () => {
        eventManager.removeListener(eventListener);
        res.end();
    });
}