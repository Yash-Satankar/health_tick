import type { RequestHandler } from 'express';
import type { z } from 'zod';

export interface ValidationSchemas {
  params?: z.ZodType;
  query?: z.ZodType;
  body?: z.ZodType;
}

/**
 * Validates params, query and body with Zod. Parsed values are stored on `req.valid`
 * (Express 5 makes `req.query` read-only). A ZodError becomes VALIDATION_ERROR in the error handler.
 * Body schemas should be `z.strictObject` so unknown fields are rejected.
 */
export function validate(schemas: ValidationSchemas): RequestHandler {
  return (req, _res, next) => {
    req.valid = {
      params: schemas.params ? schemas.params.parse(req.params) : req.params,
      query: schemas.query ? schemas.query.parse(req.query) : req.query,
      body: schemas.body ? schemas.body.parse(req.body ?? {}) : req.body,
    };
    next();
  };
}

/** Typed accessor for values validated by `validate()`. */
export function valid<T>(value: unknown): T {
  return value as T;
}
