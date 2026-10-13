import { createApp } from './app.js';
import { loadEnvOrExit } from './config/env.js';
import { createDb } from './db/kysely.js';
import { createLogger } from './lib/logger.js';

const env = loadEnvOrExit();
const logger = createLogger(env.LOG_LEVEL);
const { db } = createDb(env.DATABASE_URL);

const app = createApp({ db, logger, corsOrigins: env.CORS_ORIGINS });

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
  // 1. stop accepting connections, 2. end long-lived streams, 3. close the pool.
  server.close();
  server.closeAllConnections();
  await db.destroy();
  logger.info('shutdown complete');
  process.exit(0);
}

process.on('SIGINT', () => void shutdown('SIGINT'));
process.on('SIGTERM', () => void shutdown('SIGTERM'));
