/** npm run progress:reset [-- --user <uuid>] → clears a user's progress (default: DEMO_USER_ID). */
import { parseArgs } from 'node:util';
import { z } from 'zod';
import { resetProgress } from '../src/admin/progress.js';
import { loadEnvOrExit } from '../src/config/env.js';
import { createDb } from '../src/db/kysely.js';

const env = loadEnvOrExit();
const { values } = parseArgs({ options: { user: { type: 'string' } } });
const userId = z.uuid().safeParse(values.user ?? env.DEMO_USER_ID);
if (!userId.success) {
  console.error('--user must be a UUID');
  process.exit(1);
}

const { db } = createDb(env.DATABASE_URL, 1);
try {
  const result = await resetProgress(db, userId.data);
  const summary = Object.entries(result.deleted)
    .map(([table, n]) => `${table}=${n}`)
    .join(', ');
  console.log(`Reset progress for ${result.userId}: deleted ${summary}; health points set to 0.`);
} catch (error) {
  console.error((error as Error).message);
  process.exitCode = 1;
} finally {
  await db.destroy();
}
