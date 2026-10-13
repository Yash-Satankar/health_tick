import { Router } from 'express';
import type { createJourneyController } from './journey.controller.js';

export function journeyRoutes(controller: ReturnType<typeof createJourneyController>): Router {
  const router = Router();
  router.get('/journey', controller.get);
  return router;
}
