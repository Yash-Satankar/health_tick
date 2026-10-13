import type { RequestHandler } from 'express';
import { valid } from '../../middleware/validate.js';
import type { LessonParams } from '../lessons/lessons.schemas.js';
import type { SavedService } from './saved.service.js';

export function createSavedController(service: SavedService): {
  save: RequestHandler;
  unsave: RequestHandler;
} {
  const handler =
    (saved: boolean): RequestHandler =>
    async (req, res) => {
      const { lessonId } = valid<LessonParams>(req.valid.params);
      res.json({ data: await service.setSaved(req.user.id, lessonId, saved) });
    };
  return { save: handler(true), unsave: handler(false) };
}
