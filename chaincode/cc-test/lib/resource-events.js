/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const { Contract } = require('fabric-contract-api');

class ResourceEvents extends Contract {

	// CreateResource issues a new resource to the world state with given details.
	async CreateResource(ctx, pid, uri, hash, timestamp, owners) {
		const exists = await this.ResourceExists(ctx, pid);
		if (exists) 
			throw new Error(`The resource ${pid} already exists`);
		
		const resource = {
			PID: pid,
			URI: uri,
			hash: hash,
			timestamp: timestamp,
			owners: owners,
		};

		const resourceBuffer = Buffer.from(JSON.stringify(resource));
		await ctx.stub.putState(pid, resourceBuffer);
		ctx.stub.setEvent('CreateResource', resourceBuffer);
		return JSON.stringify(resource);
	}

	// ReadResource returns the resource stored in the world state with given id.
	async ReadResource(ctx, pid) {
		const exists = await this.ResourceExists(ctx, pid);
		if (!exists) 
			throw new Error(`The resource ${pid} does not exist`);
		
		const resourceJSON = await ctx.stub.getState(pid);
		ctx.stub.setEvent('ReadResource', resourceJSON);
		return resourceJSON.toString();
	}

	async ResourceExists(ctx, pid) {
		const resourceJSON = await ctx.stub.getState(pid);
		return resourceJSON && resourceJSON.length > 0;
	}
}

module.exports = ResourceEvents;
