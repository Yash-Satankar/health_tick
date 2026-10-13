import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import type { createLessonsController } from './lessons.controller.js';
import { LessonParams } from './lessons.schemas.js';

export function lessonsRoutes(controller: ReturnType<typeof createLessonsController>): Router {
  const router = Router();
  router.get('/lessons/:lessonId', validate({ params: LessonParams }), controller.get);
  return router;
}
