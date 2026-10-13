import { databaseName, loadDotEnv } from '../../src/config/env.js';

/**
 * Returns TEST_DATABASE_URL after checking it points at a database whose name ends in `_test`.
 * Tests must never run against the development database.
 */
export function assertTestDatabaseUrl(url: string | undefined): string {
  if (!url) throw new Error('TEST_DATABASE_URL is not set (see .env.example)');
  const name = databaseName(url);
  if (!name.endsWith('_test')) {
    throw new Error(`Refusing to run tests against database "${name}": its name must end in _test`);
  }
  return url;
}

export function testDatabaseUrl(): string {
  loadDotEnv();
  return assertTestDatabaseUrl(process.env.TEST_DATABASE_URL);
}
