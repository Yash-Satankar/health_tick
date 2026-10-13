import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { resetProgress } from '../../src/admin/progress.js';
import { sequenceRng } from '../../src/lib/rng.js';
import {
  answerFor,
  api,
  completeLesson,
  createApiApp,
  lessonId,
  markNodesCompleted,
  nodeId,
  questionPages,
} from '../helpers/api.js';
import { createTestDb } from '../helpers/app.js';
import { DEMO_USER_ID, resetAndSeed } from '../helpers/seed.js';

const { db } = createTestDb();
// Deterministic feedback selection: always the first message of the pool (ordered by key).
const app = createApiApp(db, { rng: sequenceRng([0]) });
const client = api(app);
const OTHER_USER = '22222222-2222-4222-8222-222222222222';

beforeAll(async () => {
  await resetAndSeed(db);
  await db.insertInto('users').values({ id: OTHER_USER, display_name: 'Other' }).execute();
});
beforeEach(async () => {
  await resetProgress(db, DEMO_USER_ID);
  await resetProgress(db, OTHER_USER);
});
afterAll(() => db.destroy());

async function startFoodZones() {
  await markNodesCompleted(db, ['beginner_day_1']);
  const id = await lessonId(db, 'keystone_habit_2_food_zones');
  const res = await client.post(`/lessons/${id}/attempts`);
  expect(res.status).toBe(201);
  return {
    lessonId: id,
    attemptId: res.body.data.attemptId as string,
    pages: await questionPages(db, 'keystone_habit_2_food_zones'),
  };
}

describe('POST /lessons/:id/attempts', () => {
  it('creates an in_progress attempt with the current content version', async () => {
    const id = await lessonId(db, 'welcome_to_health_tick');
    const res = await client.post(`/lessons/${id}/attempts`);
    expect(res.status).toBe(201);
    const version = (await db.selectFrom('content_state').select('version').executeTakeFirstOrThrow())
      .version;
    expect(res.body.data).toEqual({
      attemptId: expect.any(String),
      lessonId: id,
      startedAt: expect.any(String),
      contentVersion: version,
    });
  });

  it('403 LESSON_LOCKED on a locked lesson, 404 on unknown', async () => {
    const locked = await client.post(
      `/lessons/${await lessonId(db, 'keystone_habit_2_food_zones')}/attempts`,
    );
    expect(locked.status).toBe(403);
    expect(locked.body.error.code).toBe('LESSON_LOCKED');
    expect((await client.post('/lessons/11111111-1111-4111-8111-111111111111/attempts')).status).toBe(404);
  });
});

describe('PUT /attempts/:id/answers/:pageId', () => {
  it('a wrong graded answer returns feedback with the highlighted correct answer and explanation', async () => {
    const { attemptId, pages } = await startFoodZones();
    const raisins = pages[1]!; // "100g raisins vs grapes"
    const res = await client.put(`/attempts/${attemptId}/answers/${raisins.id}`, answerFor(raisins, false));
    expect(res.status).toBe(200);
    expect(res.body.data).toEqual({
      pageId: raisins.id,
      isCorrect: false,
      feedback: {
        // rng = 0 → first active "incorrect" message ordered by key (incorrect_dont_worry)
        headline: "That's not correct, but don't worry—you've got this.",
        illustration: expect.objectContaining({ url: expect.stringMatching(/^\/static\/assets\/feedback_/) }),
        correctAnswers: ['Raisins'],
        explanation: expect.stringContaining('Raisins are simply dehydrated grapes'),
      },
    });
  });

  it('a correct graded answer returns the correct-outcome feedback; empty explanation is null', async () => {
    const { attemptId, pages } = await startFoodZones();
    const first = pages[0]!; // explanation: "" in the YAML
    const res = await client.put(`/attempts/${attemptId}/answers/${first.id}`, answerFor(first, true));
    expect(res.body.data.isCorrect).toBe(true);
    expect(res.body.data.feedback.headline).toBe("That's right! You nailed it.");
    expect(res.body.data.feedback.illustration.url).toBe('/static/assets/feedback_correct.png');
    expect(res.body.data.feedback.explanation).toBeNull();
  });

  it('rotates the headline with the injected RNG', async () => {
    const rotating = api(createApiApp(db, { rng: sequenceRng([0, 0.99]) }));
    await markNodesCompleted(db, ['beginner_day_1']);
    const id = await lessonId(db, 'keystone_habit_2_food_zones');
    const attemptId = (await rotating.post(`/lessons/${id}/attempts`)).body.data.attemptId;
    const page = (await questionPages(db, 'keystone_habit_2_food_zones'))[1]!;
    const a = await rotating.put(`/attempts/${attemptId}/answers/${page.id}`, answerFor(page, false));
    const b = await rotating.put(`/attempts/${attemptId}/answers/${page.id}`, answerFor(page, false));
    expect(a.body.data.feedback.headline).not.toBe(b.body.data.feedback.headline);
  });

  it('ungraded questions get isCorrect null and no feedback; re-answering replaces the selection', async () => {
    await markNodesCompleted(db, []);
    await completeLesson(client, db, 'welcome_to_health_tick');
    const id = await lessonId(db, 'the_9_keystone_habits');
    const attemptId = (await client.post(`/lessons/${id}/attempts`)).body.data.attemptId;
    const [page] = await questionPages(db, 'the_9_keystone_habits');
    const first = await client.put(`/attempts/${attemptId}/answers/${page!.id}`, {
      optionIds: [page!.options[0]!.id, page!.options[1]!.id],
    });
    expect(first.body.data).toEqual({ pageId: page!.id, isCorrect: null, feedback: null });
    await client.put(`/attempts/${attemptId}/answers/${page!.id}`, { optionIds: [page!.options[2]!.id] });
    const stored = await db
      .selectFrom('attempt_answer_options as o')
      .innerJoin('attempt_answers as a', 'a.id', 'o.answer_id')
      .select('o.option_id')
      .where('a.attempt_id', '=', attemptId)
      .execute();
    expect(stored.map((s) => s.option_id)).toEqual([page!.options[2]!.id]);
  });

  it('422 ANSWER_INVALID for an option of another question, wrong body kind, or invalid free text', async () => {
    const { attemptId, pages } = await startFoodZones();
    const res = await client.put(`/attempts/${attemptId}/answers/${pages[0]!.id}`, {
      optionIds: [pages[1]!.options[0]!.id],
    });
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('ANSWER_INVALID');
    expect(
      (await client.put(`/attempts/${attemptId}/answers/${pages[0]!.id}`, { text: 'Raisins' })).status,
    ).toBe(422);
    expect(
      (
        await client.put(`/attempts/${attemptId}/answers/${pages[0]!.id}`, {
          optionIds: pages[0]!.options.map((o) => o.id),
        })
      ).status,
    ).toBe(422);

    await markNodesCompleted(db, ['beginner_day_2', 'beginner_day_3', 'beginner_day_4']);
    const procrast = await lessonId(db, 'procrastination_for_health');
    const pAttempt = (await client.post(`/lessons/${procrast}/attempts`)).body.data.attemptId;
    const freeText = (await questionPages(db, 'procrastination_for_health')).find(
      (p) => p.response_type === 'free_text',
    )!;
    const blank = await client.put(`/attempts/${pAttempt}/answers/${freeText.id}`, { text: '   ' });
    expect(blank.status).toBe(422);
    const tooLong = await client.put(`/attempts/${pAttempt}/answers/${freeText.id}`, {
      text: 'x'.repeat(301),
    });
    expect(tooLong.status).toBe(422);
  });

  it('400 VALIDATION_ERROR for both/neither body fields or unknown fields', async () => {
    const { attemptId, pages } = await startFoodZones();
    const url = `/attempts/${attemptId}/answers/${pages[0]!.id}`;
    for (const body of [
      {},
      { optionIds: [], text: 'x' },
      { optionIds: [pages[0]!.options[0]!.id], extra: 1 },
    ]) {
      const res = await client.put(url, body);
      expect(res.status, JSON.stringify(body)).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
    }
  });

  it("404 for another user's attempt or a page outside the lesson", async () => {
    const { attemptId, pages } = await startFoodZones();
    const other = api(app, OTHER_USER);
    const res = await other.put(`/attempts/${attemptId}/answers/${pages[0]!.id}`, answerFor(pages[0]!));
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
    const foreignPage = (await questionPages(db, 'the_9_keystone_habits'))[0]!;
    expect(
      (
        await client.put(`/attempts/${attemptId}/answers/${foreignPage.id}`, {
          optionIds: [foreignPage.options[0]!.id],
        })
      ).status,
    ).toBe(404);
  });
});

describe('POST /attempts/:id/complete', () => {
  it('422 INCOMPLETE_ATTEMPT when a question is unanswered (same content version)', async () => {
    const { attemptId } = await startFoodZones();
    const res = await client.post(`/attempts/${attemptId}/complete`);
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('INCOMPLETE_ATTEMPT');
    expect(res.body.error.details.missingPageIds).toHaveLength(4);
  });

  it('409 CONTENT_CHANGED when a question is added mid-attempt', async () => {
    const { attemptId, lessonId: id, pages } = await startFoodZones();
    for (const page of pages) await client.put(`/attempts/${attemptId}/answers/${page.id}`, answerFor(page));
    const page = await db
      .insertInto('lesson_pages')
      .values({ lesson_id: id, position: 99, page_type: 'question', cta_label: 'NEXT' })
      .returning('id')
      .executeTakeFirstOrThrow();
    await db.insertInto('page_questions').values({ page_id: page.id, response_type: 'free_text' }).execute();
    try {
      const res = await client.post(`/attempts/${attemptId}/complete`);
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('CONTENT_CHANGED');
    } finally {
      await db.deleteFrom('lesson_pages').where('id', '=', page.id).execute();
    }
  });

  it('awards points once: first completion = page count, replay = 0; ledger and total agree', async () => {
    const first = await completeLesson(client, db, 'welcome_to_health_tick');
    expect(first).toMatchObject({
      firstCompletion: true,
      healthPointsEarned: 3,
      healthPointsTotal: 3,
      nodeCompleted: false,
      unlockedNodeId: null,
      completion: {
        headline: 'You have won the day 😎',
        message: 'Rewatching programs can reignite your motivation and keep you on track.',
        asset: { url: '/static/assets/ui_completion_medal.png' },
      },
    });
    const replay = await completeLesson(client, db, 'welcome_to_health_tick');
    expect(replay).toMatchObject({ firstCompletion: false, healthPointsEarned: 0, healthPointsTotal: 3 });
    const ledger = await db
      .selectFrom('health_point_transactions')
      .selectAll()
      .where('user_id', '=', DEMO_USER_ID)
      .execute();
    expect(ledger).toHaveLength(1);
    expect(ledger[0]).toMatchObject({
      amount: 3,
      reason: 'lesson_completed',
      lesson_attempt_id: first.attemptId,
    });
    const progress = await db
      .selectFrom('user_lesson_progress')
      .selectAll()
      .where('user_id', '=', DEMO_USER_ID)
      .executeTakeFirstOrThrow();
    expect(progress.completion_count).toBe(2);
  });

  it('is idempotent under 2 concurrent requests (exactly one ledger row, identical responses)', async () => {
    const id = await lessonId(db, 'welcome_to_health_tick');
    const attemptId = (await client.post(`/lessons/${id}/attempts`)).body.data.attemptId;
    const [a, b] = await Promise.all([
      client.post(`/attempts/${attemptId}/complete`),
      client.post(`/attempts/${attemptId}/complete`),
    ]);
    expect([a.status, b.status]).toEqual([200, 200]);
    expect(a.body.data).toEqual(b.body.data);
    const ledger = await db
      .selectFrom('health_point_transactions')
      .select('id')
      .where('user_id', '=', DEMO_USER_ID)
      .execute();
    expect(ledger).toHaveLength(1);
    const again = await client.post(`/attempts/${attemptId}/complete`);
    expect(again.body.data).toEqual(a.body.data);
  });

  it('the checkpoint unlocks the Insider status', async () => {
    await markNodesCompleted(db, [
      'beginner_day_1',
      'beginner_day_2',
      'beginner_day_3',
      'beginner_day_4',
      'beginner_day_5',
      'beginner_day_6',
    ]);
    const result = await completeLesson(client, db, 'beginner_checkpoint_quiz');
    expect(result.nodeCompleted).toBe(true);
    expect(result.unlockedNodeId).toBe(await nodeId(db, 'insider_day_1'));
    expect(result.completion.message).toMatch(/Insider status is now unlocked/);
    const journey = (await client.get('/journey')).body.data;
    expect(journey.statuses[1].levels[0].nodes[0].state).toBe('available');
  });

  it('404 for an unknown or foreign attempt', async () => {
    expect((await client.post('/attempts/11111111-1111-4111-8111-111111111111/complete')).status).toBe(404);
    const id = await lessonId(db, 'welcome_to_health_tick');
    const attemptId = (await client.post(`/lessons/${id}/attempts`)).body.data.attemptId;
    expect((await api(app, OTHER_USER).post(`/attempts/${attemptId}/complete`)).status).toBe(404);
  });
});

describe('POST /attempts/:id/abandon', () => {
  it('204, idempotent; abandoned attempts award nothing and reject answers/complete', async () => {
    const { attemptId, pages } = await startFoodZones();
    expect((await client.post(`/attempts/${attemptId}/abandon`)).status).toBe(204);
    expect((await client.post(`/attempts/${attemptId}/abandon`)).status).toBe(204);
    const answer = await client.put(`/attempts/${attemptId}/answers/${pages[0]!.id}`, answerFor(pages[0]!));
    expect(answer.status).toBe(409);
    expect(answer.body.error.code).toBe('ATTEMPT_NOT_ACTIVE');
    const complete = await client.post(`/attempts/${attemptId}/complete`);
    expect(complete.status).toBe(409);
    expect(complete.body.error.code).toBe('ATTEMPT_NOT_ACTIVE');
    const user = await db
      .selectFrom('users')
      .select('health_points_total')
      .where('id', '=', DEMO_USER_ID)
      .executeTakeFirstOrThrow();
    expect(user.health_points_total).toBe(0);
  });

  it('409 when abandoning a completed attempt; 404 for unknown', async () => {
    const { attemptId } = await completeLesson(client, db, 'welcome_to_health_tick');
    const res = await client.post(`/attempts/${attemptId}/abandon`);
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('ATTEMPT_NOT_ACTIVE');
    expect((await client.post('/attempts/11111111-1111-4111-8111-111111111111/abandon')).status).toBe(404);
  });
});
