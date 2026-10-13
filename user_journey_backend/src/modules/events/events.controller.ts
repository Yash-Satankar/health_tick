import type { RequestHandler } from 'express';
import type { EventsHub } from './events.service.js';

export function createEventsController(hub: EventsHub): { stream: RequestHandler } {
  return {
    stream: async (_req, res) => {
      await hub.connect(res);
    },
  };
}
