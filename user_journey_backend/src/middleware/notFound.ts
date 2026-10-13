import type { RequestHandler } from 'express';
import { AppError } from '../lib/errors.js';

export const notFound: RequestHandler = (_req, _res, next) => {
  next(AppError.notFound('Route not found'));
};
