// health.ts
// Health check route

import { Router, Request, Response } from 'express';
import { HealthResponse } from '../types';

const router = Router();

router.get('/', (_req: Request, res: Response) => {
  const body: HealthResponse = { status: 'ok' };
  res.json(body);
});

export default router;
