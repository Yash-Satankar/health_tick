import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import type { createSearchController } from './search.controller.js';
import { SearchQuery } from './search.schemas.js';

/** Must be mounted before the lessons router so `/lessons/search` is not taken as a lesson id. */
export function searchRoutes(controller: ReturnType<typeof createSearchController>): Router {
  const router = Router();
  router.get('/lessons/search', validate({ query: SearchQuery }), controller.search);
  return router;
}
