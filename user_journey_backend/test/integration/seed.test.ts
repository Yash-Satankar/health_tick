import { sql } from 'kysely';
import { afterAll, beforeEach, describe, expect, it } from 'vitest';
import { setNodeCount } from '../../src/admin/nodeCount.js';
import { resetProgress } from '../../src/admin/progress.js';
import { createTestDb } from '../helpers/app.js';
import { DEMO_USER_ID, contentVersion, realContent, seedTestDb, truncateAll } from '../helpers/seed.js';

const { db } = createTestDb();
afterAll(() => db.destroy());

const TABLES = [
  'media_assets',
  'app_copy',
  'feedback_reasons',
  'answer_feedback_messages',
  'journey_statuses',
  'journey_levels',
  'journey_nodes',
  'lessons',
  'lesson_pages',
  'page_blocks',
  'page_questions',
  'question_options',
  'users',
] as const;

async function rowCounts(): Promise<Record<string, number>> {
  const counts: Record<string, number> = {};
  for (const table of TABLES) {
    const { rows } = await sql<{ n: number }>`select count(*)::int as n from ${sql.table(table)}`.execute(db);
    counts[table] = rows[0]!.n;
  }
  return counts;
}

const levelNodes = (levelKey: string) =>
  db
    .selectFrom('journey_nodes as n')
    .innerJoin('journey_levels as l', 'l.id', 'n.level_id')
    .select(['n.key', 'n.node_type', 'n.position', 'n.is_published', 'n.title'])
    .where('l.key', '=', levelKey)
    .orderBy('n.position')
    .execute();

beforeEach(() => truncateAll(db));

describe('db:seed', () => {
  it('seeds the reference journey (Beginner 6 nodes + checkpoint, Insider 3 nodes) and the demo user', async () => {
    const stats = await seedTestDb(db);
    expect(stats.inserted.lessons).toBe(30);
    const beginner = await levelNodes('beginner_l1');
    expect(beginner.map((n) => n.node_type)).toEqual([...Array(6).fill('lesson'), 'checkpoint']);
    expect((await levelNodes('insider_l2')).map((n) => n.title)).toEqual(['Day 7', 'Day 8', 'Day 9']);
    const user = await db.selectFrom('users').selectAll().where('id', '=', DEMO_USER_ID).executeTakeFirst();
    expect(user?.display_name).toBe('Yash');
    // accordion children are stored as page_blocks with parent_block_id set
    const children = await db
      .selectFrom('page_blocks')
      .select('id')
      .where('parent_block_id', 'is not', null)
      .execute();
    expect(children).toHaveLength(4);
  });

  it('is idempotent: a second run writes nothing (same row counts, same content version)', async () => {
    await seedTestDb(db);
    const counts = await rowCounts();
    const version = await contentVersion(db);
    const second = await seedTestDb(db);
    expect(second).toEqual({ inserted: {}, updated: {}, deleted: {} });
    expect(await rowCounts()).toEqual(counts);
    expect(await contentVersion(db)).toBe(version);
  });

  it('applies content edits in place and keeps option ids when labels change', async () => {
    await seedTestDb(db);
    const before = await db.selectFrom('question_options').select(['id', 'label']).orderBy('id').execute();
    const { model } = realContent();
    const lesson = model.statuses[0]!.levels[0]!.nodes[1]!.lessons[0]!; // food zones lesson
    lesson.title = 'Keystone Habit #2: Balance your food zones (edited)';
    const question = lesson.pages[1]!.question!;
    question.options[0]!.label = 'Edited option label';
    const stats = await seedTestDb(db, model);
    expect(stats.updated.lessons).toBe(1);
    expect(stats.inserted).toEqual({});
    const after = await db.selectFrom('question_options').select(['id', 'label']).orderBy('id').execute();
    expect(after.map((o) => o.id)).toEqual(before.map((o) => o.id));
    expect(after.some((o) => o.label === 'Edited option label')).toBe(true);
  });
});

describe('demo:set-node-count', () => {
  const template = () => realContent().model.placeholderTemplate;

  it('creates, unpublishes and republishes lesson nodes, keeping the checkpoint last', async () => {
    await seedTestDb(db);
    const up = await setNodeCount(db, 'insider_l2', 5, template());
    expect(up.created).toEqual(['demo_insider_l2_4', 'demo_insider_l2_5']);
    let nodes = await levelNodes('insider_l2');
    expect(nodes.filter((n) => n.is_published).map((n) => n.title)).toEqual([
      'Day 7',
      'Day 8',
      'Day 9',
      'Day 10',
      'Day 11',
    ]);

    const down = await setNodeCount(db, 'insider_l2', 3, template());
    expect(down.unpublished).toEqual(['demo_insider_l2_4', 'demo_insider_l2_5']);
    nodes = await levelNodes('insider_l2');
    expect(nodes).toHaveLength(5); // never deleted
    expect(nodes.filter((n) => n.is_published)).toHaveLength(3);

    const beginner = await setNodeCount(db, 'beginner_l1', 8, template());
    expect(beginner.created).toEqual(['demo_beginner_l1_7', 'demo_beginner_l1_8']);
    const beginnerNodes = await levelNodes('beginner_l1');
    expect(beginnerNodes.at(-1)).toMatchObject({ node_type: 'checkpoint', position: 8, is_published: true });

    await setNodeCount(db, 'beginner_l1', 2, template());
    const reduced = (await levelNodes('beginner_l1')).filter((n) => n.is_published);
    expect(reduced.map((n) => n.key)).toEqual(['beginner_day_1', 'beginner_day_2', 'beginner_checkpoint']);
  });

  it('rejects unknown levels and invalid counts', async () => {
    await seedTestDb(db);
    await expect(setNodeCount(db, 'nope', 3, template())).rejects.toThrow(/Unknown level/);
    await expect(setNodeCount(db, 'insider_l2', -1, template())).rejects.toThrow(/between 0 and 60/);
    await expect(setNodeCount(db, 'insider_l2', 61, template())).rejects.toThrow(/between 0 and 60/);
  });

  it('a later seed unpublishes demo nodes again and is then a no-op', async () => {
    await seedTestDb(db);
    await setNodeCount(db, 'insider_l2', 4, template());
    await seedTestDb(db);
    expect((await levelNodes('insider_l2')).filter((n) => n.is_published)).toHaveLength(3);
    expect(await seedTestDb(db)).toEqual({ inserted: {}, updated: {}, deleted: {} });
  });
});

describe('progress:reset', () => {
  it("deletes the user's progress rows and resets the total", async () => {
    await seedTestDb(db);
    const lesson = await db
      .selectFrom('lessons')
      .select(['id', 'node_id'])
      .limit(1)
      .executeTakeFirstOrThrow();
    const attempt = await db
      .insertInto('lesson_attempts')
      .values({
        user_id: DEMO_USER_ID,
        lesson_id: lesson.id,
        content_version: 1,
        status: 'completed',
        completed_at: new Date(),
      })
      .returning('id')
      .executeTakeFirstOrThrow();
    await db
      .insertInto('health_point_transactions')
      .values({ user_id: DEMO_USER_ID, amount: 5, reason: 'lesson_completed', lesson_attempt_id: attempt.id })
      .execute();
    const now = new Date();
    await db
      .insertInto('user_lesson_progress')
      .values({
        user_id: DEMO_USER_ID,
        lesson_id: lesson.id,
        first_completed_at: now,
        last_completed_at: now,
      })
      .execute();
    await db
      .insertInto('user_node_completions')
      .values({ user_id: DEMO_USER_ID, node_id: lesson.node_id })
      .execute();
    await db.insertInto('saved_lessons').values({ user_id: DEMO_USER_ID, lesson_id: lesson.id }).execute();
    await db.updateTable('users').set({ health_points_total: 5 }).where('id', '=', DEMO_USER_ID).execute();

    const result = await resetProgress(db, DEMO_USER_ID);
    expect(result.deleted).toEqual({
      health_point_transactions: 1,
      lesson_attempts: 1,
      user_lesson_progress: 1,
      user_node_completions: 1,
      saved_lessons: 1,
    });
    const user = await db
      .selectFrom('users')
      .select('health_points_total')
      .where('id', '=', DEMO_USER_ID)
      .executeTakeFirstOrThrow();
    expect(user.health_points_total).toBe(0);
    await expect(resetProgress(db, '11111111-1111-4111-8111-111111111111')).rejects.toThrow(/Unknown user/);
  });
});
