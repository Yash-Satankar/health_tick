import pg from 'pg';
import { databaseName } from '../../src/config/env.js';
import { createDb } from '../../src/db/kysely.js';
import { migrateToLatest } from '../../src/db/migrate.js';
import { testDatabaseUrl } from './testDb.js';

/**
 * Runs once before all test files: drops and recreates the `_test` database (allowed by the
 * project rules; the name is checked by testDatabaseUrl) and migrates it fresh.
 */
export default async function setup(): Promise<void> {
  const url = testDatabaseUrl();
  const name = databaseName(url);
  const maintenanceUrl = new URL(url);
  maintenanceUrl.pathname = '/postgres';

  const admin = new pg.Client({ connectionString: maintenanceUrl.toString() });
  try {
    await admin.connect();
  } catch (error) {
    throw new Error(
      `Test database server is not reachable (${(error as Error).message}). Start it with "docker compose up -d".`,
      { cause: error },
    );
  }
  try {
    const ident = pg.escapeIdentifier(name);
    await admin.query(`DROP DATABASE IF EXISTS ${ident} WITH (FORCE)`);
    await admin.query(`CREATE DATABASE ${ident}`);
  } finally {
    await admin.end().catch(() => {});
  }

  const { db } = createDb(url, 1);
  try {
    await migrateToLatest(db);
  } finally {
    await db.destroy();
  }
}
