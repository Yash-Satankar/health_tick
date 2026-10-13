import type { RequestHandler } from 'express';
import { valid } from '../../middleware/validate.js';
import type { LessonParams } from '../lessons/lessons.schemas.js';
import type { FeedbackBody } from './feedback.schemas.js';
import type { FeedbackService } from './feedback.service.js';

export function createFeedbackController(service: FeedbackService): { submit: RequestHandler } {
  return {
    submit: async (req, res) => {
      const { lessonId } = valid<LessonParams>(req.valid.params);
      const body = valid<FeedbackBody>(req.valid.body);
      res.status(201).json({ data: await service.submit(req.user.id, lessonId, body) });
    },
  };
}
