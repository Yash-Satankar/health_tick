import type { RequestHandler } from 'express';
import { valid } from '../../middleware/validate.js';
import type { LessonParams } from './lessons.schemas.js';
import type { LessonsService } from './lessons.service.js';

export function createLessonsController(service: LessonsService): { get: RequestHandler } {
  return {
    get: async (req, res) => {
      const { lessonId } = valid<LessonParams>(req.valid.params);
      res.json({ data: await service.getLesson(req.user.id, lessonId) });
    },
  };
}
