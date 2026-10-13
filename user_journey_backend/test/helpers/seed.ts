import { sql } from 'kysely';
import { seedContent } from '../../src/admin/seed.js';
import { loadAndValidateContent } from '../../src/content/load.js';
import type { ContentModel } from '../../src/content/model.js';
import { DEFAULT_CONTENT_PATHS } from '../../src/content/paths.js';
import type { Manifest } from '../../src/content/schema.js';
import type { Database } from '../../src/db/kysely.js';

export const DEMO_USER_ID = '00000000-0000-4000-8000-000000000001';

const ALL_TABLES = [
  'lesson_feedback_reasons',
  'lesson_feedback',
  'saved_lessons',
  'health_point_transactions',
  'user_node_completions',
  'user_lesson_progress',
  'attempt_answer_options',
  'attempt_answers',
  'lesson_attempts',
  'users',
  'question_options',
  'page_questions',
  'page_blocks',
  'lesson_pages',
  'lessons',
  'journey_nodes',
  'journey_levels',
  'journey_statuses',
  'answer_feedback_messages',
  'feedback_reasons',
  'app_copy',
  'media_assets',
];

/** Empties every table (content and user state). content_state keeps its single row. */
export async function truncateAll(db: Database): Promise<void> {
  await sql.raw(`TRUNCATE ${ALL_TABLES.join(', ')} RESTART IDENTITY CASCADE`).execute(db);
}

let cached: { model: ContentModel; manifest: Manifest } | null = null;

/** The real seed content (validated once per test file). Returns a fresh deep copy each call. */
export function realContent(): { model: ContentModel; manifest: Manifest } {
  if (!cached) {
    const result = loadAndValidateContent(DEFAULT_CONTENT_PATHS);
    if (!result.ok) throw new Error(`seed content invalid: ${JSON.stringify(result.issues)}`);
    cached = { model: result.model, manifest: result.manifest };
  }
  return structuredClone(cached);
}

export async function seedTestDb(db: Database, model?: ContentModel) {
  const content = realContent();
  return seedContent(db, model ?? content.model, content.manifest, {
    assetDir: DEFAULT_CONTENT_PATHS.assetDir,
    demoUserId: DEMO_USER_ID,
  });
}

/** Truncates everything and seeds the real content + demo user. */
export async function resetAndSeed(db: Database) {
  await truncateAll(db);
  return seedTestDb(db);
}

export async function contentVersion(db: Database): Promise<number> {
  return (await db.selectFrom('content_state').select('version').executeTakeFirstOrThrow()).version;
}
