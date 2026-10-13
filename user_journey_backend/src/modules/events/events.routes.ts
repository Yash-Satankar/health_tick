import { Router } from 'express';
import type { createEventsController } from './events.controller.js';

export function eventsRoutes(controller: ReturnType<typeof createEventsController>): Router {
  const router = Router();
  router.get('/events', controller.stream);
  return router;
}
