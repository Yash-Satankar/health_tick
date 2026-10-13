import path from 'node:path';
import { fileURLToPath } from 'node:url';
import cors from 'cors';
import express, { Router } from 'express';
import helmet from 'helmet';
import { sql } from 'kysely';
import { pinoHttp } from 'pino-http';
import type { Database } from './db/kysely.js';
import type { Logger } from './lib/logger.js';
import { errorHandler } from './middleware/errorHandler.js';
import { notFound } from './middleware/notFound.js';
import { requestId } from './middleware/requestId.js';

export const DEFAULT_STATIC_DIR = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../static/assets',
);

export interface AppDeps {
  db: Database;
  logger: Logger;
  corsOrigins: string[];
  /** Directory served at /static/assets. */
  staticDir?: string;
  /** Router mounted at /api/v1 (feature modules). */
  apiRouter?: Router;
}

function healthRouter(db: Database): Router {
  const router = Router();
  router.get('/health', async (_req, res) => {
    try {
      await sql`select 1`.execute(db);
      res.json({ data: { status: 'ok', db: 'ok' } });
    } catch {
      res.status(503).json({ data: { status: 'degraded', db: 'unavailable' } });
    }
  });
  return router;
}

/** Builds the Express app without listening (used by server.ts and by tests). Middleware order: SPEC §7.3. */
export function createApp(deps: AppDeps): express.Express {
  const app = express();
  app.disable('x-powered-by');
  app.set('etag', 'weak');

  app.use(requestId);
  app.use(
    pinoHttp({
      logger: deps.logger,
      genReqId: (req) => (req as express.Request).id,
      // Only method, url and id: never bodies or headers.
      serializers: {
        req: (req: { id: string; method: string; url: string }) => ({
          id: req.id,
          method: req.method,
          url: req.url,
        }),
        res: (res: { statusCode: number }) => ({ statusCode: res.statusCode }),
      },
      customLogLevel: (_req, res, err) => (err || res.statusCode >= 500 ? 'error' : 'info'),
    }),
  );
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.use(
    cors({
      origin: deps.corsOrigins.includes('*') ? '*' : deps.corsOrigins,
      exposedHeaders: ['X-Request-Id', 'ETag'],
    }),
  );
  app.use(express.json({ limit: '100kb' }));
  app.use(
    '/static/assets',
    express.static(deps.staticDir ?? DEFAULT_STATIC_DIR, {
      maxAge: '1h',
      etag: true,
      index: false,
      redirect: false,
      dotfiles: 'deny',
      fallthrough: true,
    }),
  );

  // /health is served both at the root and under /api/v1 (no X-User-Id required).
  app.use(healthRouter(deps.db));
  app.use('/api/v1', healthRouter(deps.db));
  if (deps.apiRouter) app.use('/api/v1', deps.apiRouter);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}
