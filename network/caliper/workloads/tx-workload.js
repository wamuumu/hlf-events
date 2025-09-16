const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class TxWorkload extends WorkloadModuleBase {

    constructor() {
        super();
        this.txIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.contractName = roundArguments.contractName || "cc-test";
        this.functionName = roundArguments.functionName || "CreateResource";
        this.roundRobin = roundArguments.roundRobin || false;
        this.invokerMspIds = Array.from(sutAdapter.connectorConfiguration.defaultInvokerMap.keys());
        this.defaultMspId = roundArguments.defaultMspId || this.invokerMspIds[0];
        if (this.roundRobin)
            this.defaultMspId = this.invokerMspIds[workerIndex % this.invokerMspIds.length];
    }

    async submitTransaction() {    
        this.txIndex++;
        const request = this.createWriteRequest();
        const tx = await this.sutAdapter.sendRequests(request);
    }

    createWriteRequest() {
        const PID = `pid_${this.workerIndex}_${this.txIndex}_${Date.now()}_${Math.random()}`; // Ensure uniqueness
        const randomHash = Math.random().toString(36).substring(2, 15);
        const randomTimestamp = (Date.now() + Math.floor(Math.random() * 100000)).toString();

        const request = {
            contractId: this.contractName,
            contractFunction: this.functionName,
            contractArguments: [
                PID, 
                "url", 
                randomHash, 
                randomTimestamp, 
                JSON.stringify(["owner1", "owner2"])
            ],
            invokerMspId: this.defaultMspId,
            readOnly: false,
        };

        return request;
    }
}

module.exports.createWorkloadModule = () => { return new TxWorkload() };
