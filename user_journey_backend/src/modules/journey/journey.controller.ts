import type { RequestHandler } from 'express';
import type { JourneyService } from './journey.service.js';

/** True if any entity tag in an If-None-Match header matches `etag` (weak comparison). */
export function etagMatches(ifNoneMatch: string | undefined, etag: string): boolean {
  if (!ifNoneMatch) return false;
  if (ifNoneMatch.trim() === '*') return true;
  const strip = (tag: string) => tag.trim().replace(/^W\//, '');
  return ifNoneMatch.split(',').some((tag) => strip(tag) === strip(etag));
}

export function createJourneyController(service: JourneyService): { get: RequestHandler } {
  return {
    get: async (req, res) => {
      const etag = await service.etag(req.user.id);
      res.setHeader('ETag', etag);
      res.setHeader('Cache-Control', 'private, no-cache');
      if (etagMatches(req.get('if-none-match'), etag)) {
        res.status(304).end();
        return;
      }
      res.json({ data: await service.getJourney(req.user.id) });
    },
  };
}
