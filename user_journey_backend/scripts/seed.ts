/**
 * npm run db:seed [-- --test] → validates the content, then upserts it by key in one transaction and creates
 * the demo user (DEMO_USER_ID) if missing. Idempotent: a second run reports no changes.
 */
import { seedContent } from '../src/admin/seed.js';
import { databaseName, loadEnvOrExit } from '../src/config/env.js';
import { formatIssues, loadAndValidateContent } from '../src/content/load.js';
import { DEFAULT_CONTENT_PATHS } from '../src/content/paths.js';
import { createDb } from '../src/db/kysely.js';

const env = loadEnvOrExit();
const url = process.argv.includes('--test') ? env.TEST_DATABASE_URL : env.DATABASE_URL;
if (!url) {
  console.error('TEST_DATABASE_URL is not set');
  process.exit(1);
}

const content = loadAndValidateContent(DEFAULT_CONTENT_PATHS);
if (!content.ok) {
  console.error(`Seed aborted — content is invalid:\n${formatIssues(content.issues)}`);
  process.exit(1);
}

const { db } = createDb(url, 1);
try {
  const stats = await seedContent(db, content.model, content.manifest, {
    assetDir: DEFAULT_CONTENT_PATHS.assetDir,
    demoUserId: env.DEMO_USER_ID,
  });
  const describe = (counts: Record<string, number>) =>
    Object.entries(counts)
      .map(([table, n]) => `${table}=${n}`)
      .join(', ') || 'none';
  const version = await db.selectFrom('content_state').select('version').executeTakeFirstOrThrow();
  console.log(`Seeded ${databaseName(url)} (content version ${version.version})`);
  console.log(`  inserted: ${describe(stats.inserted)}`);
  console.log(`  updated:  ${describe(stats.updated)}`);
  console.log(`  deleted:  ${describe(stats.deleted)}`);
} catch (error) {
  console.error(`Seed failed: ${(error as Error).message}`);
  process.exitCode = 1;
} finally {
  await db.destroy();
}
