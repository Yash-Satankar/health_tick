import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { resetProgress } from '../../src/admin/progress.js';
import { api, createApiApp, lessonId } from '../helpers/api.js';
import { createTestDb } from '../helpers/app.js';
import { DEMO_USER_ID, resetAndSeed } from '../helpers/seed.js';

const { db } = createTestDb();
const client = api(createApiApp(db));

let welcome: string;
let reasons: { id: string; key: string }[];

beforeAll(async () => {
  await resetAndSeed(db);
  welcome = await lessonId(db, 'welcome_to_health_tick');
  reasons = await db.selectFrom('feedback_reasons').select(['id', 'key']).orderBy('position').execute();
});
beforeEach(async () => {
  await resetProgress(db, DEMO_USER_ID);
  await db.deleteFrom('lesson_feedback').execute();
});
afterAll(() => db.destroy());

const reason = (key: string) => reasons.find((r) => r.key === key)!.id;

describe('PUT/DELETE /lessons/:id/saved', () => {
  it('toggles idempotently and is reflected in the lesson payload', async () => {
    for (let i = 0; i < 2; i++) {
      const res = await client.put(`/lessons/${welcome}/saved`);
      expect(res.status).toBe(200);
      expect(res.body.data).toEqual({ lessonId: welcome, isSaved: true });
    }
    expect((await client.get(`/lessons/${welcome}`)).body.data.isSaved).toBe(true);
    const rows = await db
      .selectFrom('saved_lessons')
      .selectAll()
      .where('user_id', '=', DEMO_USER_ID)
      .execute();
    expect(rows).toHaveLength(1);
    for (let i = 0; i < 2; i++) {
      const res = await client.delete(`/lessons/${welcome}/saved`);
      expect(res.body.data).toEqual({ lessonId: welcome, isSaved: false });
    }
    expect((await client.get(`/lessons/${welcome}`)).body.data.isSaved).toBe(false);
  });

  it('404 for an unknown lesson', async () => {
    const res = await client.put('/lessons/11111111-1111-4111-8111-111111111111/saved');
    expect(res.status).toBe(404);
  });
});

describe('POST /lessons/:id/feedback', () => {
  it('stores reasons, comment and page', async () => {
    const page = await db
      .selectFrom('lesson_pages')
      .select('id')
      .where('lesson_id', '=', welcome)
      .executeTakeFirstOrThrow();
    const res = await client.post(`/lessons/${welcome}/feedback`, {
      reasonIds: [reason('too_text_heavy'), reason('others')],
      comment: '  The image did not load  ',
      pageId: page.id,
    });
    expect(res.status).toBe(201);
    const stored = await db
      .selectFrom('lesson_feedback')
      .selectAll()
      .where('id', '=', res.body.data.feedbackId)
      .executeTakeFirstOrThrow();
    expect(stored).toMatchObject({
      user_id: DEMO_USER_ID,
      lesson_id: welcome,
      page_id: page.id,
      comment: 'The image did not load',
    });
    const linked = await db
      .selectFrom('lesson_feedback_reasons')
      .select('reason_id')
      .where('feedback_id', '=', stored.id)
      .execute();
    expect(linked).toHaveLength(2);
  });

  it('accepts a reason without comment, or a comment without reason', async () => {
    expect(
      (await client.post(`/lessons/${welcome}/feedback`, { reasonIds: [reason('hard_to_read')] })).status,
    ).toBe(201);
    expect((await client.post(`/lessons/${welcome}/feedback`, { comment: 'Nice' })).status).toBe(201);
  });

  it.each([
    ['no reason and no comment', {}],
    ['blank comment only', { comment: '   ' }],
    ['"Others" without comment', { reasonIds: ['others'] }],
    ['unknown reason', { reasonIds: ['33333333-3333-4333-8333-333333333333'] }],
  ])('422 FEEDBACK_INVALID: %s', async (_label, body: { reasonIds?: string[]; comment?: string }) => {
    const payload = {
      ...body,
      reasonIds: body.reasonIds?.map((r) => (r === 'others' ? reason('others') : r)),
    };
    const res = await client.post(`/lessons/${welcome}/feedback`, payload);
    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('FEEDBACK_INVALID');
  });

  it('400 for unknown fields or an oversized comment; 404 for an unknown lesson', async () => {
    expect((await client.post(`/lessons/${welcome}/feedback`, { comment: 'x', rating: 5 })).status).toBe(400);
    expect((await client.post(`/lessons/${welcome}/feedback`, { comment: 'x'.repeat(1001) })).status).toBe(
      400,
    );
    expect(
      (await client.post('/lessons/11111111-1111-4111-8111-111111111111/feedback', { comment: 'x' })).status,
    ).toBe(404);
  });
});
