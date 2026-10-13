import { readFileSync } from 'node:fs';
import { sql, type Kysely } from 'kysely';
import type { Migration, MigrationProvider } from 'kysely/migration';

const readSql = (file: string): string => readFileSync(new URL(`./${file}`, import.meta.url), 'utf8');

/**
 * Migrations are registered explicitly (not discovered from the file system), which keeps them
 * working the same on Windows and under tsx. 001 executes the approved schema v1 file verbatim.
 */
const migrations: Record<string, Migration> = {
  '001_schema_v1': {
    async up(db: Kysely<unknown>) {
      await sql.raw(readSql('001_schema_v1.sql')).execute(db);
    },
  },
};

export const migrationProvider: MigrationProvider = {
  getMigrations: async () => migrations,
};
