import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import request from 'supertest';
import { afterAll, describe, expect, it } from 'vitest';
import { createDb } from '../../src/db/kysely.js';
import { createTestApp, createTestDb } from '../helpers/app.js';

const handle = createTestDb();
afterAll(() => handle.db.destroy());

describe('GET /health', () => {
  it('reports ok when the database is reachable (root and /api/v1)', async () => {
    const app = createTestApp({ db: handle.db });
    for (const url of ['/health', '/api/v1/health']) {
      const res = await request(app).get(url);
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ data: { status: 'ok', db: 'ok' } });
      expect(res.headers['x-request-id']).toBeDefined();
    }
  });

  it('returns 503 when the database is unreachable', async () => {
    const down = createDb('postgres://nobody:nothing@127.0.0.1:1/unreachable_test', 1);
    try {
      const res = await request(createTestApp({ db: down.db })).get('/health');
      expect(res.status).toBe(503);
      expect(res.body.data.db).toBe('unavailable');
    } finally {
      await down.db.destroy();
    }
  });
});

describe('GET /static/assets', () => {
  const dir = mkdtempSync(path.join(tmpdir(), 'ht-static-'));
  writeFileSync(path.join(dir, 'icon.png'), Buffer.from([0x89, 0x50, 0x4e, 0x47]));
  const app = createTestApp({ db: handle.db, staticDir: dir });

  it('serves files with caching headers', async () => {
    const res = await request(app).get('/static/assets/icon.png');
    expect(res.status).toBe(200);
    expect(res.headers['cache-control']).toBe('public, max-age=3600');
    expect(res.headers.etag).toBeDefined();
  });

  it('does not list directories or allow path traversal', async () => {
    expect((await request(app).get('/static/assets/')).status).toBe(404);
    const traversal = await request(app).get('/static/assets/..%2f..%2fpackage.json');
    expect(traversal.status).toBe(404);
    expect(traversal.body.error.code).toBe('NOT_FOUND');
  });

  it('returns the JSON 404 envelope for missing files', async () => {
    const res = await request(app).get('/static/assets/missing.png');
    expect(res.status).toBe(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });
});
