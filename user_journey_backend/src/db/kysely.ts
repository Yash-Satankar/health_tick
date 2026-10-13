import { Kysely, PostgresDialect } from 'kysely';
import pg from 'pg';
import type { DB } from './types.js';

// bigint (int8) columns hold small values here (content version, ledger ids): parse them as numbers.
pg.types.setTypeParser(pg.types.builtins.INT8, (value) => Number(value));
// Keep `date` values as plain 'YYYY-MM-DD' strings (no implicit local-time conversion).
pg.types.setTypeParser(pg.types.builtins.DATE, (value) => value);

export type Database = Kysely<DB>;

export interface DbHandle {
  db: Database;
  pool: pg.Pool;
}

export function createDb(connectionString: string, poolSize = 10): DbHandle {
  const pool = new pg.Pool({ connectionString, max: poolSize, connectionTimeoutMillis: 5_000 });
  // An idle client error (e.g. the server restarted) must not crash the process.
  pool.on('error', () => {});
  const db = new Kysely<DB>({ dialect: new PostgresDialect({ pool }) });
  return { db, pool };
}
