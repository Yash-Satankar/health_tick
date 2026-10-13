import { randomUUID } from 'node:crypto';
import type { RequestHandler } from 'express';

const VALID_REQUEST_ID = /^[A-Za-z0-9._:-]{1,128}$/;

/** Echoes a well-formed incoming `X-Request-Id` or generates one, and exposes it as `req.id`. */
export const requestId: RequestHandler = (req, res, next) => {
  const incoming = req.get('x-request-id');
  const id = incoming && VALID_REQUEST_ID.test(incoming) ? incoming : randomUUID();
  req.id = id;
  res.setHeader('X-Request-Id', id);
  next();
};
