import type { Kysely } from 'kysely';
import { Migrator } from 'kysely/migration';
import { migrationProvider } from './migrations/index.js';

export interface MigrationOutcome {
  applied: string[];
}

/** Applies all pending migrations. Throws if any migration fails (each runs in its own transaction). */
// Migrations are schema-agnostic, so they take Kysely<any> (as Kysely's own Migrator does).
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export async function migrateToLatest(db: Kysely<any>): Promise<MigrationOutcome> {
  const migrator = new Migrator({ db, provider: migrationProvider });
  const { error, results = [] } = await migrator.migrateToLatest();
  const failed = results.find((result) => result.status === 'Error');
  if (error || failed) {
    const name = failed ? ` (${failed.migrationName})` : '';
    throw new Error(`Migration failed${name}: ${error instanceof Error ? error.message : String(error)}`, {
      cause: error,
    });
  }
  return {
    applied: results.filter((result) => result.status === 'Success').map((result) => result.migrationName),
  };
}
