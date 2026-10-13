import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { resetProgress } from '../../src/admin/progress.js';
import { api, completeLesson, createApiApp, lessonId, markNodesCompleted } from '../helpers/api.js';
import { createTestDb } from '../helpers/app.js';
import { DEMO_USER_ID, resetAndSeed } from '../helpers/seed.js';

const { db } = createTestDb();
const app = createApiApp(db, { now: () => new Date() });
const client = api(app);

beforeAll(() => resetAndSeed(db));
beforeEach(() => resetProgress(db, DEMO_USER_ID));
afterAll(() => db.destroy());

describe('X-User-Id (SPEC 6.1)', () => {
  it.each([
    ['missing', undefined],
    ['not a uuid', 'abc'],
    ['unknown user', '11111111-1111-4111-8111-111111111111'],
  ])('rejects %s with 401 USER_NOT_IDENTIFIED', async (_label, header) => {
    const req = request(app).get('/api/v1/bootstrap');
    const res = await (header ? req.set('X-User-Id', header) : req);
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('USER_NOT_IDENTIFIED');
    expect(res.body.error.requestId).toBe(res.headers['x-request-id']);
  });
});

describe('GET /bootstrap', () => {
  it('returns copy, ui assets, reasons and the user', async () => {
    const res = await client.get('/bootstrap');
    expect(res.status).toBe(200);
    const data = res.body.data;
    expect(data.contentVersion).toBeGreaterThan(1);
    expect(data.user).toEqual({ id: DEMO_USER_ID, displayName: 'Yash', healthPointsTotal: 0 });
    expect(data.copy['journey.title']).toBe('Your Journey');
    expect(Object.keys(data.copy).some((key) => key.startsWith('ui_asset.'))).toBe(false);
    expect(data.assets.lockedNode.url).toBe('/static/assets/node_locked.png');
    expect(data.assets.completionMedal).toMatchObject({
      url: '/static/assets/ui_completion_medal.png',
      width: 229,
      height: 287,
      format: 'png',
    });
    expect(data.feedbackReasons).toHaveLength(6);
    expect(data.feedbackReasons.at(-1)).toMatchObject({ key: 'others', label: 'Others', requiresText: true });
  });
});

describe('GET /home', () => {
  it("fresh user: streak 0 and today's task is the welcome lesson", async () => {
    const res = await client.get('/home');
    expect(res.body.data).toEqual({
      user: { displayName: 'Yash', healthPointsTotal: 0, streakDays: 0 },
      todayTask: {
        lessonId: await lessonId(db, 'welcome_to_health_tick'),
        lessonTitle: 'Welcome to Health Tick!',
        nodeId: expect.any(String),
        statusTitle: 'Beginner',
      },
    });
  });

  it('after a completion: streak 1, points added, next task', async () => {
    await completeLesson(client, db, 'welcome_to_health_tick');
    const res = await client.get('/home');
    expect(res.body.data.user).toEqual({ displayName: 'Yash', healthPointsTotal: 3, streakDays: 1 });
    expect(res.body.data.todayTask.lessonTitle).toBe('The 9 Keystone Habits');
  });

  it('todayTask is null when every lesson is completed', async () => {
    const nodes = await db
      .selectFrom('journey_nodes')
      .select('key')
      .where('is_published', '=', true)
      .execute();
    await markNodesCompleted(
      db,
      nodes.map((n) => n.key),
    );
    expect((await client.get('/home')).body.data.todayTask).toBeNull();
  });
});

describe('GET /journey', () => {
  it('returns Beginner (LEVEL-1, 6 nodes + checkpoint) and Insider (LEVEL-2, 3 nodes); fresh user states', async () => {
    const res = await client.get('/journey');
    expect(res.status).toBe(200);
    const [beginner, insider] = res.body.data.statuses;
    expect(beginner).toMatchObject({
      key: 'beginner',
      title: 'Beginner',
      cardTheme: { backgroundColor: '#F9E4C9', shadowColor: '#DBC4A5', textColor: '#1C1C1C' },
    });
    const level1 = beginner.levels[0];
    expect(level1).toMatchObject({ label: 'LEVEL-1', title: 'Psychology of weight' });
    expect(level1.illustration.url).toBe('/static/assets/card_beginner_illustration.png');
    expect(level1.nodes.map((n: { type: string }) => n.type)).toEqual([
      ...Array(6).fill('lesson'),
      'checkpoint',
    ]);
    expect(insider.levels[0].label).toBe('LEVEL-2');
    expect(insider.levels[0].nodes).toHaveLength(3);
    const allNodes = [...level1.nodes, ...insider.levels[0].nodes];
    expect(allNodes.map((n: { state: string }) => n.state)).toEqual([
      'available',
      ...Array(9).fill('locked'),
    ]);
    expect(level1.nodes[0].lessons[0]).toEqual({
      id: expect.any(String),
      title: 'Welcome to Health Tick!',
      state: 'available',
      completedAt: null,
    });
    expect(level1.nodes[0].icon).toMatchObject({ url: '/static/assets/node_psychology.png', width: 114 });
  });

  it('sends a weak ETag and answers 304 when it matches; the ETag changes after a completion', async () => {
    const first = await client.get('/journey');
    const etag = first.headers.etag as string;
    expect(etag).toMatch(/^W\/"c\d+-p0"$/);
    const cached = await client.get('/journey').set('If-None-Match', etag);
    expect(cached.status).toBe(304);
    expect(cached.text).toBe('');

    await completeLesson(client, db, 'welcome_to_health_tick');
    const after = await client.get('/journey').set('If-None-Match', etag);
    expect(after.status).toBe(200);
    expect(after.headers.etag).not.toBe(etag);
    const node1 = after.body.data.statuses[0].levels[0].nodes[0];
    expect(node1.state).toBe('available');
    expect(node1.lessons.map((l: { state: string }) => l.state)).toEqual([
      'completed',
      'available',
      'locked',
      'locked',
      'locked',
    ]);
    expect(node1.lessons[0].completedAt).toEqual(expect.any(String));
  });

  it('completing every lesson of node 1 completes it and unlocks node 2', async () => {
    for (const key of [
      'welcome_to_health_tick',
      'the_9_keystone_habits',
      'keystone_habit_1_hunger_levels',
      'little_secret_part_1',
    ]) {
      await completeLesson(client, db, key);
    }
    const last = await completeLesson(client, db, 'set_your_initial_goals');
    const journey = (await client.get('/journey')).body.data;
    const nodes = journey.statuses[0].levels[0].nodes;
    expect(last.nodeCompleted).toBe(true);
    expect(last.unlockedNodeId).toBe(nodes[1].id);
    expect(nodes[0]).toMatchObject({ state: 'completed', completedAt: expect.any(String) });
    expect(nodes[1].state).toBe('available');
    expect(nodes[2].state).toBe('locked');
  });
});

describe('GET /lessons/:lessonId', () => {
  it('returns pages and blocks and never includes correct answers', async () => {
    const id = await lessonId(db, 'welcome_to_health_tick');
    const res = await client.get(`/lessons/${id}`);
    expect(res.status).toBe(200);
    expect(res.body.data).toMatchObject({
      id,
      title: 'Welcome to Health Tick!',
      nodeType: 'lesson',
      isSaved: false,
      pageCount: 3,
    });
    const page0 = res.body.data.pages[0];
    expect(page0).toMatchObject({
      position: 0,
      type: 'content',
      ctaLabel: "THAT'S IMPRACTICAL!",
      question: null,
    });
    expect(page0.blocks[0]).toMatchObject({
      type: 'image',
      asset: { url: '/static/assets/lesson_waving_hand.png' },
    });
    expect(page0.blocks[1]).toMatchObject({
      type: 'paragraph',
      text: expect.stringContaining('{{user.name}}'),
    });
    expect(page0.blocks[3]).toMatchObject({ type: 'numbered_list', items: expect.any(Array) });
  });

  it('question payloads expose options without correctness (unlocked graded lesson)', async () => {
    await markNodesCompleted(db, ['beginner_day_1']);
    const id = await lessonId(db, 'keystone_habit_2_food_zones');
    const res = await client.get(`/lessons/${id}`);
    expect(res.status).toBe(200);
    const body = JSON.stringify(res.body);
    expect(body).not.toMatch(/is_correct|isCorrect|"correct"/);
    const q = res.body.data.pages[1].question;
    expect(q).toMatchObject({ responseType: 'single_choice', isGraded: true, maxSelections: 1 });
    expect(Object.keys(q.options[0]).sort()).toEqual(['id', 'label']);
    const types = new Set(
      res.body.data.pages.flatMap((p: { blocks: { type: string }[] }) => p.blocks.map((b) => b.type)),
    );
    expect([...types]).toEqual(
      expect.arrayContaining([
        'image',
        'paragraph',
        'heading',
        'bulleted_list',
        'callout',
        'icon_heading',
        'accordion',
      ]),
    );
    const accordion = res.body.data.pages
      .flatMap((p: { blocks: { type: string }[] }) => p.blocks)
      .find((b: { type: string }) => b.type === 'accordion');
    expect(accordion).toMatchObject({ title: expect.any(String), children: [{ type: 'bulleted_list' }] });
    const iconHeading = res.body.data.pages
      .flatMap((p: { blocks: { type: string }[] }) => p.blocks)
      .find((b: { type: string }) => b.type === 'icon_heading');
    expect(iconHeading).toMatchObject({ text: 'ZONE-1', color: '#F5A04A', asset: { width: 256 } });
  });

  it('403 LESSON_LOCKED for a locked lesson, 404 for unknown, 400 for a malformed id', async () => {
    const locked = await client.get(`/lessons/${await lessonId(db, 'keystone_habit_2_food_zones')}`);
    expect(locked.status).toBe(403);
    expect(locked.body.error.code).toBe('LESSON_LOCKED');
    const unknown = await client.get('/lessons/11111111-1111-4111-8111-111111111111');
    expect(unknown.status).toBe(404);
    expect(unknown.body.error.code).toBe('NOT_FOUND');
    const malformed = await client.get('/lessons/not-a-uuid');
    expect(malformed.status).toBe(400);
    expect(malformed.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('unpublished lessons are hidden (404) and unpublished parents hide children', async () => {
    const id = await lessonId(db, 'welcome_to_health_tick');
    await db
      .updateTable('journey_nodes')
      .set({ is_published: false })
      .where('key', '=', 'beginner_day_1')
      .execute();
    try {
      expect((await client.get(`/lessons/${id}`)).status).toBe(404);
      const journey = (await client.get('/journey')).body.data;
      expect(journey.statuses[0].levels[0].nodes[0].key).toBe('beginner_day_2');
      expect(journey.statuses[0].levels[0].nodes[0].state).toBe('available');
    } finally {
      await db
        .updateTable('journey_nodes')
        .set({ is_published: true })
        .where('key', '=', 'beginner_day_1')
        .execute();
    }
  });
});

describe('GET /lessons/search', () => {
  it('finds "procrast" by partial title with path and lock state', async () => {
    const res = await client.get('/lessons/search?q=procrast');
    expect(res.status).toBe(200);
    expect(res.body.data.query).toBe('procrast');
    expect(res.body.data.results[0]).toMatchObject({
      title: 'Procrastination for health',
      nodeTitle: 'Day 5',
      levelLabel: 'LEVEL-1',
      statusTitle: 'Beginner',
      state: 'locked',
    });
  });

  it('sorts by relevance or journey order and honours limit', async () => {
    const relevance = (await client.get('/lessons/search?q=keystone habit')).body.data.results;
    const journey = (await client.get('/lessons/search?q=keystone habit&sort=journey')).body.data.results;
    expect(relevance.length).toBeGreaterThanOrEqual(3);
    expect(journey.map((r: { title: string }) => r.title)).toEqual([
      'The 9 Keystone Habits',
      'Keystone Habit #1: Identify your hunger levels',
      'Keystone Habit #2: Balance your food zones',
      'Keystone Habit #3: Introduction to Mindful Eating',
    ]);
    expect(new Set(relevance.map((r: { lessonId: string }) => r.lessonId))).toEqual(
      new Set(journey.map((r: { lessonId: string }) => r.lessonId)),
    );
    const limited = (await client.get('/lessons/search?q=keystone&limit=2')).body.data.results;
    expect(limited).toHaveLength(2);
  });

  it('returns an empty list when nothing matches and validates q, sort and limit', async () => {
    expect((await client.get('/lessons/search?q=zzzzqqq')).body.data.results).toEqual([]);
    for (const query of [
      'q=a',
      'q=',
      `q=${'x'.repeat(101)}`,
      'q=ok&sort=random',
      'q=ok&limit=0',
      'q=ok&limit=51',
    ]) {
      const res = await client.get(`/lessons/search?${query}`);
      expect(res.status, query).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
  });

  it('treats LIKE wildcards literally and hides unpublished lessons', async () => {
    expect((await client.get('/lessons/search?q=%25%25')).body.data.results).toEqual([]);
    await db
      .updateTable('lessons')
      .set({ is_published: false })
      .where('key', '=', 'procrastination_for_health')
      .execute();
    try {
      const titles = (await client.get('/lessons/search?q=procrast')).body.data.results.map(
        (r: { title: string }) => r.title,
      );
      expect(titles).not.toContain('Procrastination for health');
    } finally {
      await db
        .updateTable('lessons')
        .set({ is_published: true })
        .where('key', '=', 'procrastination_for_health')
        .execute();
    }
  });
});
