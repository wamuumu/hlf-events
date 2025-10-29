import { Router } from 'express';

import {
  createResource,
  readResourcesByTimestamp,
  getEventStream
} from './controller';

const router = Router();

router.post('/create', (req, res) => createResource(req, res));
router.get('/read', (req, res) => readResourcesByTimestamp(req, res));
router.get('/events/stream', (req, res) => getEventStream(req, res));

// TODO: Add the remaining routes 

export default router;