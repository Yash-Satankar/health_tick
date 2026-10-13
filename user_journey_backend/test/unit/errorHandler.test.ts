import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { AppError } from '../../src/lib/errors.js';
import { errorHandler } from '../../src/middleware/errorHandler.js';
import { notFound } from '../../src/middleware/notFound.js';
import { requestId } from '../../src/middleware/requestId.js';
import { validate } from '../../src/middleware/validate.js';

function appThatThrows(error: unknown) {
  const app = express();
  app.use(requestId);
  app.use(express.json({ limit: '100kb' }));
  app.get('/boom', () => {
    throw error;
  });
  app.post('/strict', validate({ body: z.strictObject({ name: z.string() }) }), (req, res) => {
    res.json({ data: req.valid.body });
  });
  app.use(notFound);
  app.use(errorHandler);
  return app;
}

describe('errorHandler', () => {
  it('maps AppError to its status and code with the request id', async () => {
    const res = await request(appThatThrows(AppError.lessonLocked()))
      .get('/boom')
      .set('X-Request-Id', 'req-123');
    expect(res.status).toBe(403);
    expect(res.headers['x-request-id']).toBe('req-123');
    expect(res.body).toEqual({
      error: { code: 'LESSON_LOCKED', message: 'This lesson is locked', requestId: 'req-123' },
    });
  });

  it('hides unknown errors (no stack, no SQL)', async () => {
    const pgLike = Object.assign(new Error('relation "secret_table" does not exist'), { code: '42P01' });
    const res = await request(appThatThrows(pgLike)).get('/boom');
    expect(res.status).toBe(500);
    expect(res.body.error.code).toBe('INTERNAL_ERROR');
    expect(JSON.stringify(res.body)).not.toMatch(/secret_table|stack|\.ts:/);
    expect(res.body.error.requestId).toBe(res.headers['x-request-id']);
  });

  it('maps Zod errors and rejects unknown body fields', async () => {
    const app = appThatThrows(null);
    const ok = await request(app).post('/strict').send({ name: 'a' });
    expect(ok.body).toEqual({ data: { name: 'a' } });
    const res = await request(app).post('/strict').send({ name: 'a', extra: 1 });
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(res.body.error.details).toBeInstanceOf(Array);
  });

  it('maps malformed JSON to VALIDATION_ERROR', async () => {
    const res = await request(appThatThrows(null))
      .post('/strict')
      .set('Content-Type', 'application/json')
      .send('{"name":');
    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('returns NOT_FOUND for unknown routes and replaces a malformed request id', async () => {
    const res = await request(appThatThrows(null)).get('/nope').set('X-Request-Id', 'bad id with spaces');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
    expect(res.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);
  });
});
