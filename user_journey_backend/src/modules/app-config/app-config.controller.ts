import type { RequestHandler } from 'express';
import type { AppConfigService } from './app-config.service.js';

export function createAppConfigController(service: AppConfigService): { bootstrap: RequestHandler } {
  return {
    bootstrap: async (req, res) => {
      res.json({ data: await service.bootstrap(req.user.id) });
    },
  };
}
