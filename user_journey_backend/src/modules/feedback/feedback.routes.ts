import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import { LessonParams } from '../lessons/lessons.schemas.js';
import type { createFeedbackController } from './feedback.controller.js';
import { FeedbackBody } from './feedback.schemas.js';

export function feedbackRoutes(controller: ReturnType<typeof createFeedbackController>): Router {
  const router = Router();
  router.post(
    '/lessons/:lessonId/feedback',
    validate({ params: LessonParams, body: FeedbackBody }),
    controller.submit,
  );
  return router;
}
