import { createApp, type AppDeps } from '../../src/app.js';
import { createDb, type DbHandle } from '../../src/db/kysely.js';
import { createLogger } from '../../src/lib/logger.js';
import { testDatabaseUrl } from './testDb.js';

export const silentLogger = createLogger('silent');

export function createTestDb(): DbHandle {
  return createDb(testDatabaseUrl(), 5);
}

export function createTestApp(overrides: Partial<AppDeps> & Pick<AppDeps, 'db'>) {
  return createApp({ logger: silentLogger, corsOrigins: ['*'], ...overrides });
}
