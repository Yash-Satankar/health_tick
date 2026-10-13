import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import { LessonParams } from '../lessons/lessons.schemas.js';
import type { createSavedController } from './saved.controller.js';

export function savedRoutes(controller: ReturnType<typeof createSavedController>): Router {
  const router = Router();
  router.put('/lessons/:lessonId/saved', validate({ params: LessonParams }), controller.save);
  router.delete('/lessons/:lessonId/saved', validate({ params: LessonParams }), controller.unsave);
  return router;
}
