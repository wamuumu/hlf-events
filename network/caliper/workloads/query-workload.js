const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class QueryWorkload extends WorkloadModuleBase {

    constructor() {
        super();
        this.txIndex = 0;
        this.existingAssets = [];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.contractName = roundArguments.contractName || "cc-test";
        this.functionName = roundArguments.functionName || "ReadResource";
        this.workerIndex = workerIndex;
        this.roundRobin = roundArguments.roundRobin || false;
        this.organizations = Array.from(sutAdapter.connectorConfiguration.defaultInvokerMap.keys());
        this.defaultOrganization = this.roundRobin ? this.organizations[workerIndex % this.organizations.length] : this.organizations[0];
        
        const request = {
            contractId: this.contractName,
            contractFunction: "ReadAllResources",
            contractArguments: [],
            readOnly: true,
        };
        const tx = await this.sutAdapter.sendRequests(request);
        this.existingAssets = JSON.parse(Buffer.from(tx.status.result).toString());
    }

    async submitTransaction() {    
        this.txIndex++;
        const request = this.createReadRequest();
        const tx = await this.sutAdapter.sendRequests(request);
    }

    createReadRequest() {
        if (this.existingAssets.length > 0) {
            const randomIndex = Math.floor(Math.random() * this.existingAssets.length);
            const randomAsset = this.existingAssets[randomIndex];

            const request = {
                contractId: this.contractName,
                contractFunction: this.functionName,
                contractArguments: [randomAsset.PID],
                invokerMspId: this.defaultOrganization,
                readOnly: true,
            };

            return request;
        } else
            throw new Error("No existing assets to query");
    }
}

module.exports.createWorkloadModule = () => { return new QueryWorkload() };
