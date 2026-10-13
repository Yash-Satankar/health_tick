import { sql } from 'kysely';
import pg from 'pg';
import { afterAll, describe, expect, it } from 'vitest';
import { migrateToLatest } from '../../src/db/migrate.js';
import { createTestDb } from '../helpers/app.js';
import { testDatabaseUrl } from '../helpers/testDb.js';

const { db } = createTestDb();
afterAll(() => db.destroy());

const contentVersion = async () =>
  (await db.selectFrom('content_state').select('version').executeTakeFirstOrThrow()).version;

describe('migration 001 (schema v1)', () => {
  it('has been applied and is idempotent', async () => {
    const tables = await sql<{ n: number }>`
      select count(*)::int as n from information_schema.tables
      where table_schema = 'public' and table_name not like 'kysely_%'`.execute(db);
    expect(tables.rows[0]?.n).toBe(23);
    await expect(migrateToLatest(db)).resolves.toEqual({ applied: [] });
  });

  it('bumps content_state.version and NOTIFYs content_changed once per content statement, on commit', async () => {
    const listener = new pg.Client({ connectionString: testDatabaseUrl() });
    await listener.connect();
    const payloads: string[] = [];
    listener.on('notification', (msg) => {
      if (msg.channel === 'content_changed' && msg.payload) payloads.push(msg.payload);
    });
    await listener.query('LISTEN content_changed');
    try {
      const before = await contentVersion();
      await db.transaction().execute(async (trx) => {
        await trx.insertInto('app_copy').values({ key: 'schema_test.one', value: 'One' }).execute();
        await trx.insertInto('app_copy').values({ key: 'schema_test.two', value: 'Two' }).execute();
      });
      const after = await contentVersion();
      expect(after).toBe(before + 2);
      await expect.poll(() => payloads.length).toBe(2);
      expect(payloads).toEqual([String(before + 1), String(before + 2)]);
    } finally {
      await listener.end();
      await db.deleteFrom('app_copy').where('key', 'like', 'schema_test.%').execute();
    }
  });

  it('does not bump the version for user-state tables and maintains updated_at', async () => {
    const before = await contentVersion();
    const user = await db
      .insertInto('users')
      .values({ display_name: 'Schema Test' })
      .returning(['id', 'updated_at'])
      .executeTakeFirstOrThrow();
    await new Promise((resolve) => setTimeout(resolve, 20));
    const updated = await db
      .updateTable('users')
      .set({ display_name: 'Renamed' })
      .where('id', '=', user.id)
      .returning('updated_at')
      .executeTakeFirstOrThrow();
    expect(updated.updated_at.getTime()).toBeGreaterThan(user.updated_at.getTime());
    expect(await contentVersion()).toBe(before);
    await db.deleteFrom('users').where('id', '=', user.id).execute();
  });

  it('enforces block shape and question constraints', async () => {
    await expect(
      sql`insert into page_questions (page_id, response_type, is_graded)
          values (gen_random_uuid(), 'free_text', true)`.execute(db),
    ).rejects.toThrow(/ck_graded_is_choice|violates/);
  });
});
