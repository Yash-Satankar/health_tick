import { createApp } from './app.js';
import { loadEnvOrExit } from './config/env.js';
import { createApiRouter } from './container.js';
import { createDb } from './db/kysely.js';
import { ContentListener } from './db/listen.js';
import { createLogger } from './lib/logger.js';
import { EventsHub } from './modules/events/events.service.js';

const env = loadEnvOrExit();
const logger = createLogger(env.LOG_LEVEL);
const { db } = createDb(env.DATABASE_URL);

const listener = new ContentListener({ connectionString: env.DATABASE_URL, logger });
const eventsHub = new EventsHub(listener, env.SSE_HEARTBEAT_MS, async () =>
  Number((await db.selectFrom('content_state').select('version').executeTakeFirstOrThrow()).version),
);
// The listener reconnects by itself; a failed first connect must not stop the API from serving.
void listener.start();

const app = createApp({
  db,
  logger,
  corsOrigins: env.CORS_ORIGINS,
  apiRouter: createApiRouter({ db, timeZone: env.APP_TIMEZONE, eventsHub }),
});

const server = app.listen(env.PORT, () => {
  logger.info({ port: env.PORT, env: env.NODE_ENV }, 'HealthTick API listening');
});

let shuttingDown = false;
async function shutdown(signal: string): Promise<void> {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info({ signal }, 'shutting down');
  const forceExit = setTimeout(() => process.exit(1), 10_000);
  forceExit.unref();
  // SPEC §7.5: stop accepting connections → end SSE streams → release the LISTEN client → close the pool.
  server.close();
  eventsHub.close();
  server.closeIdleConnections();
  await listener.stop();
  await db.destroy();
  logger.info('shutdown complete');
  process.exit(0);
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
