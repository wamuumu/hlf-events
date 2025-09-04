const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class QueryWorkload extends WorkloadModuleBase {

    constructor() {
        super();
        this.txIndex = 0;
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        this.workerIndex = workerIndex;

        if (roundArguments) {
            this.contractName = roundArguments.contractName || "cc-test";
            this.functionName = roundArguments.functionName || "ReadResource";
        }
    }

    async submitTransaction() {
        this.txIndex++;

        const PID = `pid_${this.workerIndex}_${this.txIndex}`;

        const request = {
            contractId: this.contractName,
            contractFunction: this.functionName,
            contractArguments: [PID],
            readOnly: true,
        }

        await this.sutAdapter.sendRequests(request);
    }
}

function createWorkloadModule() {
    return new QueryWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;
