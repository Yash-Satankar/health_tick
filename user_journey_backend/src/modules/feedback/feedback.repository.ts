import type { Database } from '../../db/kysely.js';

export class FeedbackRepository {
  constructor(private readonly db: Database) {}

  async activeReasons(ids: string[]) {
    if (ids.length === 0) return [];
    return this.db
      .selectFrom('feedback_reasons')
      .select(['id', 'requires_text'])
      .where('id', 'in', ids)
      .where('is_active', '=', true)
      .execute();
  }

  async pageBelongsToLesson(pageId: string, lessonId: string): Promise<boolean> {
    const row = await this.db
      .selectFrom('lesson_pages')
      .select('id')
      .where('id', '=', pageId)
      .where('lesson_id', '=', lessonId)
      .executeTakeFirst();
    return row !== undefined;
  }

  async insert(values: {
    userId: string;
    lessonId: string;
    pageId: string | null;
    comment: string | null;
    reasonIds: string[];
  }): Promise<string> {
    return this.db.transaction().execute(async (trx) => {
      const feedback = await trx
        .insertInto('lesson_feedback')
        .values({
          user_id: values.userId,
          lesson_id: values.lessonId,
          page_id: values.pageId,
          comment: values.comment,
        })
        .returning('id')
        .executeTakeFirstOrThrow();
      if (values.reasonIds.length > 0) {
        await trx
          .insertInto('lesson_feedback_reasons')
          .values(values.reasonIds.map((reasonId) => ({ feedback_id: feedback.id, reason_id: reasonId })))
          .execute();
      }
      return feedback.id;
    });
  }
}
