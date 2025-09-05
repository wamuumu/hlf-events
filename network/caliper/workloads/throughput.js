const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

class ThroughputWorkload extends WorkloadModuleBase {

    constructor() {
        super();
        this.txIndex = 0;
        this.existingAssets = [];
    }

    async initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext) {
        await super.initializeWorkloadModule(workerIndex, totalWorkers, roundIndex, roundArguments, sutAdapter, sutContext);
        
        this.contractName = roundArguments.contractName || "cc-test";
        this.functionName = roundArguments.functionName || "CreateResource";
        this.operationType = roundArguments.operationType || "write";
        this.workerIndex = workerIndex;
        
        if (this.operationType === "read") {
            const request = {
                contractId: this.contractName,
                contractFunction: "ReadAllResources",
                contractArguments: [],
                readOnly: true,
            };
            const tx = await this.sutAdapter.sendRequests(request);
            this.existingAssets = JSON.parse(Buffer.from(tx.status.result).toString());
        }
    }

    async submitTransaction() {    
        this.txIndex++;
        let request;
        if (this.operationType === "write")
            request = this.createWriteRequest();
        else
            request = this.createReadRequest();

        if (request)
            await this.sutAdapter.sendRequests(request);
        else
            throw new Error("Cannot submit the transaction: request is null");
    }

    createWriteRequest() {
        const PID = `pid_${this.workerIndex}_${this.txIndex}_${Date.now()}_${Math.random()}`; // Ensure uniqueness
        const randomHash = Math.random().toString(36).substring(2, 15);
        const randomTimestamp = (Date.now() + Math.floor(Math.random() * 100000)).toString();

        const request = {
            contractId: this.contractName,
            contractFunction: "CreateResource",
            contractArguments: [
                PID, 
                "url", 
                randomHash, 
                randomTimestamp, 
                JSON.stringify(["owner1", "owner2"])
            ],
            readOnly: false,
        };

        return request;
    }

    createReadRequest() {
        if (this.existingAssets.length > 0) {
            const randomIndex = Math.floor(Math.random() * this.existingAssets.length);
            const randomAsset = this.existingAssets[randomIndex];

            const request = {
                contractId: this.contractName,
                contractFunction: "ReadResource",
                contractArguments: [randomAsset.PID],
                readOnly: true,
            };

            return request;
        }

        return null;
    }
}

module.exports.createWorkloadModule = () => { return new ThroughputWorkload() };
