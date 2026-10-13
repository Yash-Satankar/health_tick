import type { ErrorRequestHandler } from 'express';
import { ZodError } from 'zod';
import { AppError, ErrorCode } from '../lib/errors.js';

interface BodyParserError {
  type: string;
  status?: number;
}

const isBodyParserError = (err: unknown): err is BodyParserError =>
  typeof err === 'object' && err !== null && typeof (err as { type?: unknown }).type === 'string';

/** Maps an unknown thrown value to the client-safe AppError that will be sent. */
export function toAppError(err: unknown): AppError | null {
  if (err instanceof AppError) return err;
  if (err instanceof ZodError) {
    return AppError.validation(
      'Request validation failed',
      err.issues.map((issue) => ({ path: issue.path.join('.'), message: issue.message })),
    );
  }
  if (isBodyParserError(err)) {
    if (err.type === 'entity.parse.failed') return AppError.validation('Malformed JSON body');
    if (err.type === 'entity.too.large') return AppError.validation('Request body too large');
    if (err.type === 'encoding.unsupported' || err.type === 'charset.unsupported') {
      return AppError.validation('Unsupported request body encoding');
    }
  }
  return null;
}

/**
 * Final error handler. Known errors are mapped to their code; everything else (including Postgres errors)
 * becomes INTERNAL_ERROR, with details logged on the server only — never a stack trace or SQL to the client.
 */
export const errorHandler: ErrorRequestHandler = (err, req, res, next) => {
  if (res.headersSent) {
    next(err);
    return;
  }
  const appError = toAppError(err);
  if (appError) {
    res.status(appError.status).json({
      error: {
        code: appError.code,
        message: appError.message,
        ...(appError.details === undefined ? {} : { details: appError.details }),
        requestId: req.id,
      },
    });
    return;
  }
  req.log?.error({ err }, 'unhandled error');
  res.status(500).json({
    error: { code: ErrorCode.INTERNAL_ERROR, message: 'Something went wrong', requestId: req.id },
  });
};
