import { EventEmitter } from 'node:events';
import type express from 'express';
import request from 'supertest';
import { expect } from 'vitest';
import { createApiRouter } from '../../src/container.js';
import type { Database } from '../../src/db/kysely.js';
import type { Rng } from '../../src/lib/rng.js';
import { EventsHub } from '../../src/modules/events/events.service.js';
import { createTestApp } from './app.js';
import { DEMO_USER_ID } from './seed.js';

class StaticVersionSource extends EventEmitter<{ change: [number] }> {
  version = 0;
}

export function createApiApp(
  db: Database,
  options: { rng?: Rng; now?: () => Date; eventsHub?: EventsHub } = {},
): express.Express {
  const eventsHub = options.eventsHub ?? new EventsHub(new StaticVersionSource(), 25_000, async () => 1);
  const apiRouter = createApiRouter({
    db,
    timeZone: 'Asia/Kolkata',
    eventsHub,
    ...(options.rng ? { rng: options.rng } : {}),
    ...(options.now ? { now: options.now } : {}),
  });
  return createTestApp({ db, apiRouter });
}

/** Supertest agent helpers that send X-User-Id. */
export function api(app: express.Express, userId: string = DEMO_USER_ID) {
  const withUser = (test: request.Test) => test.set('X-User-Id', userId);
  return {
    get: (url: string) => withUser(request(app).get(`/api/v1${url}`)),
    post: (url: string, body?: object) => withUser(request(app).post(`/api/v1${url}`)).send(body ?? {}),
    put: (url: string, body?: object) => withUser(request(app).put(`/api/v1${url}`)).send(body ?? {}),
    delete: (url: string) => withUser(request(app).delete(`/api/v1${url}`)),
  };
}

export type Api = ReturnType<typeof api>;

export async function lessonId(db: Database, key: string): Promise<string> {
  return (await db.selectFrom('lessons').select('id').where('key', '=', key).executeTakeFirstOrThrow()).id;
}

export async function nodeId(db: Database, key: string): Promise<string> {
  return (await db.selectFrom('journey_nodes').select('id').where('key', '=', key).executeTakeFirstOrThrow())
    .id;
}

export async function questionPages(db: Database, lessonKey: string) {
  const pages = await db
    .selectFrom('lesson_pages as p')
    .innerJoin('lessons as l', 'l.id', 'p.lesson_id')
    .innerJoin('page_questions as q', 'q.page_id', 'p.id')
    .select(['p.id', 'p.position', 'q.response_type', 'q.is_graded', 'q.min_selections'])
    .where('l.key', '=', lessonKey)
    .orderBy('p.position')
    .execute();
  const options = await db
    .selectFrom('question_options')
    .select(['id', 'page_id', 'is_correct', 'label'])
    .where('page_id', 'in', pages.length ? pages.map((p) => p.id) : ['00000000-0000-0000-0000-000000000000'])
    .orderBy('position')
    .execute();
  return pages.map((page) => ({ ...page, options: options.filter((o) => o.page_id === page.id) }));
}

/** A valid answer body for a question page (correct when `correct` is true and the question is graded). */
export function answerFor(
  page: Awaited<ReturnType<typeof questionPages>>[number],
  correct = true,
): { optionIds: string[] } | { text: string } {
  if (page.response_type === 'free_text') return { text: 'Walk 10 minutes after dinner' };
  if (page.is_graded) {
    const pick = page.options.filter((o) => o.is_correct === correct);
    return { optionIds: page.response_type === 'single_choice' ? [pick[0]!.id] : pick.map((o) => o.id) };
  }
  return { optionIds: page.options.slice(0, Math.max(1, page.min_selections ?? 1)).map((o) => o.id) };
}

/** Starts an attempt, answers every question correctly and completes it. Returns the completion payload. */
export async function completeLesson(client: Api, db: Database, lessonKey: string) {
  const id = await lessonId(db, lessonKey);
  const start = await client.post(`/lessons/${id}/attempts`);
  expect(start.status, JSON.stringify(start.body)).toBe(201);
  const attemptId = start.body.data.attemptId as string;
  for (const page of await questionPages(db, lessonKey)) {
    const res = await client.put(`/attempts/${attemptId}/answers/${page.id}`, answerFor(page));
    expect(res.status, JSON.stringify(res.body)).toBe(200);
  }
  const done = await client.post(`/attempts/${attemptId}/complete`);
  expect(done.status, JSON.stringify(done.body)).toBe(200);
  return { attemptId, ...done.body.data };
}

/** Marks every lesson of the given nodes completed directly in the database (fast fixture). */
export async function markNodesCompleted(db: Database, nodeKeys: string[], userId: string = DEMO_USER_ID) {
  const now = new Date();
  for (const key of nodeKeys) {
    const node = await nodeId(db, key);
    const lessons = await db.selectFrom('lessons').select('id').where('node_id', '=', node).execute();
    for (const lesson of lessons) {
      await db
        .insertInto('user_lesson_progress')
        .values({ user_id: userId, lesson_id: lesson.id, first_completed_at: now, last_completed_at: now })
        .onConflict((oc) => oc.doNothing())
        .execute();
    }
    await db
      .insertInto('user_node_completions')
      .values({ user_id: userId, node_id: node })
      .onConflict((oc) => oc.doNothing())
      .execute();
  }
}
