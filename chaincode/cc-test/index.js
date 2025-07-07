/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const resourceEvents = require('./lib/resource-events');

module.exports.resourceEvents = resourceEvents;
module.exports.contracts = [resourceEvents];
