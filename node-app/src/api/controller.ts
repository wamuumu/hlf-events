import { Request, Response } from 'express';

export const createResource = async (req: Request, res: Response) => {

    const contract_manager = req.app.get('contractManager');
    
    // Implementation for creating a resource
    if (!contract_manager) {
        return res.status(500).json({ error: 'Contract manager not initialized' });
    }

    const { pid, uri, hash, timestamp, owners } = req.body;

    console.log('Received createResource request with body:', pid, uri, hash, timestamp, owners);

    if (!pid || !uri || !hash || !timestamp || !owners) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    const resource = [
        pid,
        uri,
        hash,
        timestamp,
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

export const readResource = async (req: Request, res: Response) => {

    const contract_manager = req.app.get('contractManager');

    // Implementation for reading a resource
    if (!contract_manager) {
        return res.status(500).json({ error: 'Contract manager not initialized' });
    }

    const { pid } = req.params;

    if (!pid) {
        return res.status(400).json({ error: 'PID parameter is required' });
    }

    try {
        const resource = await contract_manager.readResource([pid]);
        return res.status(200).json(resource);
    } catch (error) {
        console.error('Error during resource retrieval:', error);
        return res.status(500).json({ error: 'Failed to retrieve resource' });
    }
};