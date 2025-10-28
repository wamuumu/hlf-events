import { Router } from 'express';

import {
  createResource,
  readResource
} from './controller';

const router = Router();

router.post('/create', (req, res) => createResource(req, res));
router.get('/read/:pid', (req, res) => readResource(req, res));

// TODO: Add the remaining routes 

export default router;