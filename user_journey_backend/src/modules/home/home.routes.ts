import { Router } from 'express';
import type { createHomeController } from './home.controller.js';

export function homeRoutes(controller: ReturnType<typeof createHomeController>): Router {
  const router = Router();
  router.get('/home', controller.get);
  return router;
}
