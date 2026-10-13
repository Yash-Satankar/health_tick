import type { Database } from '../db/kysely.js';

export interface ResetProgressResult {
  userId: string;
  deleted: Record<string, number>;
}

/**
 * `progress:reset` (SPEC §7.6): deletes a user's attempts (answers cascade), lesson progress,
 * node completions, saved lessons and points ledger, and resets their health-point total — in one transaction.
 */
export async function resetProgress(db: Database, userId: string): Promise<ResetProgressResult> {
  return db.transaction().execute(async (trx) => {
    const user = await trx
      .selectFrom('users')
      .select('id')
      .where('id', '=', userId)
      .forUpdate()
      .executeTakeFirst();
    if (!user) throw new Error(`Unknown user ${userId}`);
    const deleted: Record<string, number> = {};
    const run = async (table: string, query: { executeTakeFirst(): Promise<{ numDeletedRows: bigint }> }) => {
      deleted[table] = Number((await query.executeTakeFirst()).numDeletedRows);
    };
    await run(
      'health_point_transactions',
      trx.deleteFrom('health_point_transactions').where('user_id', '=', userId),
    );
    await run('lesson_attempts', trx.deleteFrom('lesson_attempts').where('user_id', '=', userId));
    await run('user_lesson_progress', trx.deleteFrom('user_lesson_progress').where('user_id', '=', userId));
    await run('user_node_completions', trx.deleteFrom('user_node_completions').where('user_id', '=', userId));
    await run('saved_lessons', trx.deleteFrom('saved_lessons').where('user_id', '=', userId));
    await trx.updateTable('users').set({ health_points_total: 0 }).where('id', '=', userId).execute();
    return { userId, deleted };
  });
}
