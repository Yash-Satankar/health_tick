import type { RequestHandler } from 'express';
import { valid } from '../../middleware/validate.js';
import type { LessonParams } from '../lessons/lessons.schemas.js';
import type { AnswerBody, AnswerParams, AttemptParams } from './attempts.schemas.js';
import type { AttemptsService } from './attempts.service.js';

export function createAttemptsController(service: AttemptsService) {
  const start: RequestHandler = async (req, res) => {
    const { lessonId } = valid<LessonParams>(req.valid.params);
    res.status(201).json({ data: await service.start(req.user.id, lessonId) });
  };
  const answer: RequestHandler = async (req, res) => {
    const { attemptId, pageId } = valid<AnswerParams>(req.valid.params);
    const body = valid<AnswerBody>(req.valid.body);
    res.json({ data: await service.answer(req.user.id, attemptId, pageId, body) });
  };
  const complete: RequestHandler = async (req, res) => {
    const { attemptId } = valid<AttemptParams>(req.valid.params);
    res.json({ data: await service.complete(req.user.id, attemptId) });
  };
  const abandon: RequestHandler = async (req, res) => {
    const { attemptId } = valid<AttemptParams>(req.valid.params);
    await service.abandon(req.user.id, attemptId);
    res.status(204).end();
  };
  return { start, answer, complete, abandon };
}
