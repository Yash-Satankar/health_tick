/**
 * npm run demo:set-node-count -- --level <levelKey> --count <n>
 * Changes the number of published lesson nodes in a level, in one transaction (one real-time update).
 */
import { parseArgs } from 'node:util';
import { NodeCountError, setNodeCount } from '../src/admin/nodeCount.js';
import { loadEnvOrExit } from '../src/config/env.js';
import { formatIssues, loadAndValidateContent } from '../src/content/load.js';
import { DEFAULT_CONTENT_PATHS } from '../src/content/paths.js';
import { createDb } from '../src/db/kysely.js';

const env = loadEnvOrExit();
const { values } = parseArgs({ options: { level: { type: 'string' }, count: { type: 'string' } } });
if (!values.level || values.count === undefined || !/^\d+$/.test(values.count)) {
  console.error('Usage: npm run demo:set-node-count -- --level <levelKey> --count <n>');
  process.exit(1);
}

// The placeholder template (CTA + completion copy) for created demo lessons comes from the content file.
const content = loadAndValidateContent(DEFAULT_CONTENT_PATHS);
if (!content.ok) {
  console.error(`Content is invalid:\n${formatIssues(content.issues)}`);
  process.exit(1);
}

const { db } = createDb(env.DATABASE_URL, 1);
try {
  const result = await setNodeCount(
    db,
    values.level,
    Number(values.count),
    content.model.placeholderTemplate,
  );
  console.log(
    `Level ${result.levelKey}: ${result.publishedLessonNodes} published lesson node(s). ` +
      `created=[${result.created.join(', ')}] published=[${result.published.join(', ')}] ` +
      `unpublished=[${result.unpublished.join(', ')}]`,
  );
} catch (error) {
  console.error(error instanceof NodeCountError ? error.message : `Failed: ${(error as Error).message}`);
  process.exitCode = 1;
} finally {
  await db.destroy();
}
