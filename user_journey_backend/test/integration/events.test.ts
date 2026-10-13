import http from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { setNodeCount } from '../../src/admin/nodeCount.js';
import { createApiRouter } from '../../src/container.js';
import { ContentListener } from '../../src/db/listen.js';
import { EventsHub } from '../../src/modules/events/events.service.js';
import { createTestApp, createTestDb, silentLogger } from '../helpers/app.js';
import { DEMO_USER_ID, contentVersion, realContent, resetAndSeed } from '../helpers/seed.js';
import { testDatabaseUrl } from '../helpers/testDb.js';

const { db } = createTestDb();
const listener = new ContentListener({
  connectionString: testDatabaseUrl(),
  logger: silentLogger,
  coalesceMs: 100,
});
const hub = new EventsHub(listener, 200, () => contentVersion(db));
let server: http.Server;
let port: number;

beforeAll(async () => {
  await resetAndSeed(db);
  await listener.start();
  const app = createTestApp({
    db,
    apiRouter: createApiRouter({ db, timeZone: 'Asia/Kolkata', eventsHub: hub }),
  });
  server = app.listen(0);
  await new Promise<void>((resolve) => server.once('listening', resolve));
  port = (server.address() as AddressInfo).port;
});

afterAll(async () => {
  hub.close();
  await new Promise<void>((resolve) => server.close(() => resolve()));
  await listener.stop();
  await db.destroy();
});

interface SseEvent {
  event: string;
  data: unknown;
}

/** Minimal SSE client: collects parsed events until closed. */
function openStream(userId: string | null = DEMO_USER_ID) {
  const events: SseEvent[] = [];
  let raw = '';
  let statusCode = 0;
  let headers: http.IncomingHttpHeaders = {};
  const req = http.get(
    { port, path: '/api/v1/events', headers: userId ? { 'X-User-Id': userId } : {} },
    (res) => {
      statusCode = res.statusCode ?? 0;
      headers = res.headers;
      res.setEncoding('utf8');
      res.on('data', (chunk: string) => {
        raw += chunk;
        let index: number;
        while ((index = raw.indexOf('\n\n')) !== -1) {
          const frame = raw.slice(0, index);
          raw = raw.slice(index + 2);
          const event = /^event: (.*)$/m.exec(frame)?.[1];
          const data = /^data: (.*)$/m.exec(frame)?.[1];
          if (event) events.push({ event, data: data ? JSON.parse(data) : null });
          else if (frame.startsWith('retry:')) events.push({ event: 'retry', data: frame.slice(6).trim() });
        }
      });
    },
  );
  req.on('error', () => {});
  return {
    events,
    status: () => statusCode,
    headers: () => headers,
    close: () => req.destroy(),
  };
}

const named = (events: SseEvent[], name: string) => events.filter((e) => e.event === name);

describe('GET /events (SSE)', () => {
  it('sends retry + hello, then content_changed after a content update', async () => {
    const stream = openStream();
    try {
      await expect.poll(() => named(stream.events, 'hello').length).toBe(1);
      expect(stream.status()).toBe(200);
      expect(stream.headers()['content-type']).toMatch(/text\/event-stream/);
      expect(stream.headers()['cache-control']).toBe('no-cache');
      expect(stream.headers()['x-accel-buffering']).toBe('no');
      expect(stream.events[0]).toEqual({ event: 'retry', data: '5000' });
      const hello = named(stream.events, 'hello')[0]!.data as { version: number };
      expect(hello.version).toBe(await contentVersion(db));

      await db
        .updateTable('app_copy')
        .set({ value: 'Your Journey!' })
        .where('key', '=', 'journey.title')
        .execute();
      await expect.poll(() => named(stream.events, 'content_changed').length, { timeout: 3000 }).toBe(1);
      expect(named(stream.events, 'content_changed')[0]!.data).toEqual({ version: await contentVersion(db) });
    } finally {
      stream.close();
      await db
        .updateTable('app_copy')
        .set({ value: 'Your Journey' })
        .where('key', '=', 'journey.title')
        .execute();
    }
  });

  it('demo:set-node-count changes the journey and emits exactly one event', async () => {
    const stream = openStream();
    try {
      await expect.poll(() => named(stream.events, 'hello').length).toBe(1);
      await new Promise((resolve) => setTimeout(resolve, 300)); // let earlier notifications drain
      const baseline = named(stream.events, 'content_changed').length;

      await setNodeCount(db, 'insider_l2', 5, realContent().model.placeholderTemplate);
      await expect
        .poll(() => named(stream.events, 'content_changed').length, { timeout: 3000 })
        .toBe(baseline + 1);
      await new Promise((resolve) => setTimeout(resolve, 500)); // no trailing duplicates
      expect(named(stream.events, 'content_changed')).toHaveLength(baseline + 1);
      expect(named(stream.events, 'content_changed').at(-1)!.data).toEqual({
        version: await contentVersion(db),
      });

      const res = await fetch(`http://127.0.0.1:${port}/api/v1/journey`, {
        headers: { 'X-User-Id': DEMO_USER_ID },
      });
      const journey = (await res.json()) as {
        data: { statuses: { levels: { nodes: { title: string }[] }[] }[] };
      };
      expect(journey.data.statuses[1]!.levels[0]!.nodes.map((n) => n.title)).toEqual([
        'Day 7',
        'Day 8',
        'Day 9',
        'Day 10',
        'Day 11',
      ]);
    } finally {
      stream.close();
      await setNodeCount(db, 'insider_l2', 3, realContent().model.placeholderTemplate);
    }
  });

  it('sends ping heartbeats and removes clients on disconnect', async () => {
    const stream = openStream();
    await expect.poll(() => named(stream.events, 'ping').length, { timeout: 2000 }).toBeGreaterThan(0);
    expect(hub.clientCount).toBeGreaterThan(0);
    stream.close();
    await expect.poll(() => hub.clientCount).toBe(0);
  });

  it('requires X-User-Id', async () => {
    const stream = openStream(null);
    await expect.poll(() => stream.status()).toBe(401);
    stream.close();
  });
});
