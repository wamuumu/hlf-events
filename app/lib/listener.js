class EventListener {
    constructor(connector) {
        this.connector = connector;
        this.activeListeners = new Map();
        this.isListening = false;
    }

    /** 
    * Listen for chaincode events
    */
    async listen() {

        if (this.isListening) {
            console.warn('Already listening for chaincode events.');
            return;
        }

        this.isListening = true;

        if (!this.connector.network) {
            console.error('Network is not initialized. Please connect first.');
            return;
        }

        console.log(`Listening for chaincode events...`);

        while (this.isListening) {
            try {
                let events = await this.connector.network.getChaincodeEvents(this.connector.chaincode_name);

                for await (const event of events) {
                    console.log('event');
                } 
            } catch (error) {
                console.error(`Error while listening for chaincode events: ${error.message}`);
                this.isListening = false
                break;
            }

            // Sleep for a while before checking for new events
            await new Promise(resolve => setTimeout(resolve, 5000));
        }
    }
}

module.exports = EventListener;