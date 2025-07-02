const HLFConnector = require('./lib/connect');

async function main() {

    // Create the connection and connect to the gateway
    const hlf_connector = new HLFConnector();
    const gateway = await hlf_connector.connect();

}

main();