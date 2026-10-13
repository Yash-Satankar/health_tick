import type { RequestHandler } from 'express';
import type { HomeService } from './home.service.js';

export function createHomeController(service: HomeService): { get: RequestHandler } {
  return {
    get: async (req, res) => {
      res.json({ data: await service.home(req.user.id) });
    },
  };
}
