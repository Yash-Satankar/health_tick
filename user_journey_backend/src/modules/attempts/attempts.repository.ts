import { sql, type Kysely } from 'kysely';
import { UI_ASSET_COPY_PREFIX } from '../../admin/seed.js';
import type { DB } from '../../db/types.js';

/** Queries for attempts. Every method takes the executor so it can run inside a transaction. */
export class AttemptsRepository {
  async contentVersion(db: Kysely<DB>): Promise<number> {
    return (await db.selectFrom('content_state').select('version').executeTakeFirstOrThrow()).version;
  }

  async insertAttempt(db: Kysely<DB>, userId: string, lessonId: string, contentVersion: number) {
    return db
      .insertInto('lesson_attempts')
      .values({ user_id: userId, lesson_id: lessonId, content_version: contentVersion })
      .returning(['id', 'lesson_id', 'started_at', 'content_version'])
      .executeTakeFirstOrThrow();
  }

  /** The user's attempt, locked (FOR UPDATE) for the rest of the transaction. */
  async lockAttempt(db: Kysely<DB>, attemptId: string, userId: string) {
    return db
      .selectFrom('lesson_attempts')
      .selectAll()
      .where('id', '=', attemptId)
      .where('user_id', '=', userId)
      .forUpdate()
      .executeTakeFirst();
  }

  async findAttempt(db: Kysely<DB>, attemptId: string, userId: string) {
    return db
      .selectFrom('lesson_attempts')
      .selectAll()
      .where('id', '=', attemptId)
      .where('user_id', '=', userId)
      .executeTakeFirst();
  }

  async lockUser(db: Kysely<DB>, userId: string) {
    return db
      .selectFrom('users')
      .select(['id', 'health_points_total'])
      .where('id', '=', userId)
      .forUpdate()
      .executeTakeFirstOrThrow();
  }

  async transactionNow(db: Kysely<DB>): Promise<Date> {
    const { rows } = await sql<{ now: Date }>`select now() as now`.execute(db);
    return rows[0]!.now;
  }

  async questionPage(db: Kysely<DB>, lessonId: string, pageId: string) {
    return db
      .selectFrom('lesson_pages as p')
      .innerJoin('page_questions as q', 'q.page_id', 'p.id')
      .selectAll('q')
      .where('p.id', '=', pageId)
      .where('p.lesson_id', '=', lessonId)
      .where('p.page_type', '=', 'question')
      .executeTakeFirst();
  }

  async optionsWithAnswers(db: Kysely<DB>, pageId: string) {
    return db
      .selectFrom('question_options')
      .select(['id', 'label', 'is_correct'])
      .where('page_id', '=', pageId)
      .orderBy('position')
      .execute();
  }

  async activeFeedbackMessages(db: Kysely<DB>, outcome: 'correct' | 'incorrect') {
    return db
      .selectFrom('answer_feedback_messages as m')
      .innerJoin('media_assets as a', 'a.id', 'm.illustration_asset_id')
      .select(['m.id', 'm.headline', 'm.weight', 'a.url', 'a.width', 'a.height', 'a.alt_text', 'a.format'])
      .where('m.outcome', '=', outcome)
      .where('m.is_active', '=', true)
      .orderBy('m.key')
      .execute();
  }

  async upsertAnswer(
    db: Kysely<DB>,
    values: {
      attemptId: string;
      pageId: string;
      freeText: string | null;
      isCorrect: boolean | null;
      feedbackMessageId: string | null;
      optionIds: string[];
    },
  ): Promise<void> {
    const answer = await db
      .insertInto('attempt_answers')
      .values({
        attempt_id: values.attemptId,
        page_id: values.pageId,
        free_text: values.freeText,
        is_correct: values.isCorrect,
        feedback_message_id: values.feedbackMessageId,
      })
      .onConflict((oc) =>
        oc.columns(['attempt_id', 'page_id']).doUpdateSet({
          free_text: values.freeText,
          is_correct: values.isCorrect,
          feedback_message_id: values.feedbackMessageId,
          answered_at: sql`now()`,
        }),
      )
      .returning('id')
      .executeTakeFirstOrThrow();
    // Re-answering replaces the previous selection.
    await db.deleteFrom('attempt_answer_options').where('answer_id', '=', answer.id).execute();
    if (values.optionIds.length > 0) {
      await db
        .insertInto('attempt_answer_options')
        .values(
          values.optionIds.map((optionId) => ({
            answer_id: answer.id,
            page_id: values.pageId,
            option_id: optionId,
          })),
        )
        .execute();
    }
  }

  async questionPageIds(db: Kysely<DB>, lessonId: string): Promise<string[]> {
    const rows = await db
      .selectFrom('lesson_pages')
      .select('id')
      .where('lesson_id', '=', lessonId)
      .where('page_type', '=', 'question')
      .execute();
    return rows.map((row) => row.id);
  }

  async answeredPageIds(db: Kysely<DB>, attemptId: string): Promise<Set<string>> {
    const rows = await db
      .selectFrom('attempt_answers')
      .select('page_id')
      .where('attempt_id', '=', attemptId)
      .execute();
    return new Set(rows.map((row) => row.page_id));
  }

  async pageCount(db: Kysely<DB>, lessonId: string): Promise<number> {
    const row = await db
      .selectFrom('lesson_pages')
      .select((eb) => eb.fn.countAll<string>().as('n'))
      .where('lesson_id', '=', lessonId)
      .executeTakeFirstOrThrow();
    return Number(row.n);
  }

  async hasProgress(db: Kysely<DB>, userId: string, lessonId: string): Promise<boolean> {
    const row = await db
      .selectFrom('user_lesson_progress')
      .select('lesson_id')
      .where('user_id', '=', userId)
      .where('lesson_id', '=', lessonId)
      .executeTakeFirst();
    return row !== undefined;
  }

  async awardPoints(db: Kysely<DB>, userId: string, attemptId: string, amount: number): Promise<void> {
    await db
      .insertInto('health_point_transactions')
      .values({ user_id: userId, amount, reason: 'lesson_completed', lesson_attempt_id: attemptId })
      .execute();
    await db
      .updateTable('users')
      .set((eb) => ({ health_points_total: eb('health_points_total', '+', amount) }))
      .where('id', '=', userId)
      .execute();
  }

  async upsertProgress(db: Kysely<DB>, userId: string, lessonId: string, at: Date): Promise<void> {
    await db
      .insertInto('user_lesson_progress')
      .values({ user_id: userId, lesson_id: lessonId, first_completed_at: at, last_completed_at: at })
      .onConflict((oc) =>
        oc.columns(['user_id', 'lesson_id']).doUpdateSet((eb) => ({
          last_completed_at: at,
          completion_count: eb('user_lesson_progress.completion_count', '+', 1),
        })),
      )
      .execute();
  }

  /** Published lessons of the node that the user has NOT completed. */
  async incompleteLessonsInNode(db: Kysely<DB>, userId: string, nodeId: string): Promise<number> {
    const row = await db
      .selectFrom('lessons as l')
      .leftJoin('user_lesson_progress as p', (join) =>
        join.onRef('p.lesson_id', '=', 'l.id').on('p.user_id', '=', userId),
      )
      .select((eb) => eb.fn.countAll<string>().as('n'))
      .where('l.node_id', '=', nodeId)
      .where('l.is_published', '=', true)
      .where('p.lesson_id', 'is', null)
      .executeTakeFirstOrThrow();
    return Number(row.n);
  }

  async nodeCompletion(db: Kysely<DB>, userId: string, nodeId: string) {
    return db
      .selectFrom('user_node_completions')
      .select('completed_at')
      .where('user_id', '=', userId)
      .where('node_id', '=', nodeId)
      .executeTakeFirst();
  }

  async insertNodeCompletion(db: Kysely<DB>, userId: string, nodeId: string, at: Date): Promise<void> {
    await db
      .insertInto('user_node_completions')
      .values({ user_id: userId, node_id: nodeId, completed_at: at })
      .execute();
  }

  async markCompleted(db: Kysely<DB>, attemptId: string, at: Date, points: number): Promise<void> {
    await db
      .updateTable('lesson_attempts')
      .set({ status: 'completed', completed_at: at, health_points_earned: points })
      .where('id', '=', attemptId)
      .execute();
  }

  async markAbandoned(db: Kysely<DB>, attemptId: string, userId: string): Promise<number> {
    const result = await db
      .updateTable('lesson_attempts')
      .set({ status: 'abandoned', abandoned_at: sql`now()` })
      .where('id', '=', attemptId)
      .where('user_id', '=', userId)
      .where('status', '=', 'in_progress')
      .executeTakeFirst();
    return Number(result.numUpdatedRows);
  }

  async userTotal(db: Kysely<DB>, userId: string): Promise<number> {
    return (
      await db
        .selectFrom('users')
        .select('health_points_total')
        .where('id', '=', userId)
        .executeTakeFirstOrThrow()
    ).health_points_total;
  }

  async lessonCompletion(db: Kysely<DB>, lessonId: string) {
    return db
      .selectFrom('lessons as l')
      .leftJoin('media_assets as a', 'a.id', 'l.completion_asset_id')
      .select([
        'l.node_id',
        'l.completion_headline',
        'l.completion_message',
        'a.url',
        'a.width',
        'a.height',
        'a.alt_text',
        'a.format',
      ])
      .where('l.id', '=', lessonId)
      .executeTakeFirstOrThrow();
  }

  /** The default completion medal (YAML ui_assets.completion_medal, stored as reserved app_copy). */
  async completionMedal(db: Kysely<DB>) {
    return db
      .selectFrom('app_copy as c')
      .innerJoin('media_assets as a', 'a.key', 'c.value')
      .select(['a.url', 'a.width', 'a.height', 'a.alt_text', 'a.format'])
      .where('c.key', '=', `${UI_ASSET_COPY_PREFIX}completion_medal`)
      .executeTakeFirst();
  }
}
