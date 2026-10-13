import pg from 'pg';
import { testDatabaseUrl } from './testDb.js';

/** Runs once before all test files: checks the test database URL is safe and reachable. */
export default async function setup(): Promise<void> {
  const url = testDatabaseUrl();
  const client = new pg.Client({ connectionString: url });
  try {
    await client.connect();
    await client.query('select 1');
  } catch (error) {
    throw new Error(
      `Test database is not reachable (${(error as Error).message}). Start it with "docker compose up -d".`,
      { cause: error },
    );
  } finally {
    await client.end().catch(() => {});
  }
}
