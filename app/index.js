const HLFConnector = require('./lib/connect');
const EventListener = require('./lib/listener');

async function main() {

    // Create the connector
    const connector = new HLFConnector();
    
    try {
        await connector.connect();
    } catch (error) {
        throw new Error(`Failed to connect to peer: ${error.message}`);
    }

    // Create the event listener
    const event_listener = new EventListener(connector);

    // Start listening for chaincode events
    try {
        await event_listener.listen();
    } catch (error) {
        throw new Error(`Failed to start listening for chaincode events: ${error.message}`);
    }

    // Close the connection when done
    await connector.disconnect();
    process.exit(0);
}

main();