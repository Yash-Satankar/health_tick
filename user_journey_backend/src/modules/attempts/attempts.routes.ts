import { Router } from 'express';
import { validate } from '../../middleware/validate.js';
import { LessonParams } from '../lessons/lessons.schemas.js';
import type { createAttemptsController } from './attempts.controller.js';
import { AnswerBody, AnswerParams, AttemptParams } from './attempts.schemas.js';

export function attemptsRoutes(controller: ReturnType<typeof createAttemptsController>): Router {
  const router = Router();
  router.post('/lessons/:lessonId/attempts', validate({ params: LessonParams }), controller.start);
  router.put(
    '/attempts/:attemptId/answers/:pageId',
    validate({ params: AnswerParams, body: AnswerBody }),
    controller.answer,
  );
  router.post('/attempts/:attemptId/complete', validate({ params: AttemptParams }), controller.complete);
  router.post('/attempts/:attemptId/abandon', validate({ params: AttemptParams }), controller.abandon);
  return router;
}
