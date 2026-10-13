import { Router } from 'express';
import type { createAppConfigController } from './app-config.controller.js';

export function appConfigRoutes(controller: ReturnType<typeof createAppConfigController>): Router {
  const router = Router();
  router.get('/bootstrap', controller.bootstrap);
  return router;
}
