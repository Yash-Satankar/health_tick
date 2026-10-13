/**
 * npm run db:migrate        → migrates DATABASE_URL
 * npm run db:migrate:test   → migrates TEST_DATABASE_URL (must end in _test)
 */
import { databaseName, loadEnvOrExit } from '../src/config/env.js';
import { createDb } from '../src/db/kysely.js';
import { migrateToLatest } from '../src/db/migrate.js';

const env = loadEnvOrExit();
const useTest = process.argv.includes('--test');
const url = useTest ? env.TEST_DATABASE_URL : env.DATABASE_URL;
if (!url) {
  console.error('TEST_DATABASE_URL is not set');
  process.exit(1);
}

const { db } = createDb(url, 1);
try {
  const { applied } = await migrateToLatest(db);
  console.log(
    applied.length
      ? `Migrated ${databaseName(url)}: ${applied.join(', ')}`
      : `${databaseName(url)} is already up to date`,
  );
} catch (error) {
  console.error((error as Error).message);
  process.exitCode = 1;
} finally {
  await db.destroy();
}
