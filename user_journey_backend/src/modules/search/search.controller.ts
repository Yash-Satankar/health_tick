import type { RequestHandler } from 'express';
import { valid } from '../../middleware/validate.js';
import type { SearchQuery } from './search.schemas.js';
import type { SearchService } from './search.service.js';

export function createSearchController(service: SearchService): { search: RequestHandler } {
  return {
    search: async (req, res) => {
      const { q, sort, limit } = valid<SearchQuery>(req.valid.query);
      res.json({ data: await service.search(req.user.id, q, sort, limit) });
    },
  };
}
