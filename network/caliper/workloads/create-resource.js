const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class CreateWorkload extends WorkloadModuleBase {

    constructor() {
        super();
        this.txIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        this.workerIndex = workerIndex;

        if (roundArguments) {
            this.contractName = roundArguments.contractName || "cc-test";
            this.functionName = roundArguments.functionName || "CreateResource";
        }
    }

    async submitTransaction() {    
        this.txIndex++;   

        const PID = `pid_${this.workerIndex}_${this.txIndex}`;
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
            readOnly: false,
        };

        await this.sutAdapter.sendRequests(request);
    }
}

function createWorkloadModule() {
    return new CreateWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
