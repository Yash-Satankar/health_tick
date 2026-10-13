import type { Database } from '../../db/kysely.js';

export class LessonsRepository {
  constructor(private readonly db: Database) {}

  async pages(lessonId: string) {
    return this.db
      .selectFrom('lesson_pages')
      .select(['id', 'position', 'page_type', 'cta_label'])
      .where('lesson_id', '=', lessonId)
      .orderBy('position')
      .execute();
  }

  async blocks(pageIds: string[]) {
    if (pageIds.length === 0) return [];
    return this.db
      .selectFrom('page_blocks')
      .select(['id', 'page_id', 'parent_block_id', 'position', 'block_type', 'content', 'media_asset_id'])
      .where('page_id', 'in', pageIds)
      .orderBy('position')
      .execute();
  }

  async questions(pageIds: string[]) {
    if (pageIds.length === 0) return [];
    return this.db.selectFrom('page_questions').selectAll().where('page_id', 'in', pageIds).execute();
  }

  /** Options WITHOUT is_correct — the lesson payload must never reveal answers. */
  async options(pageIds: string[]) {
    if (pageIds.length === 0) return [];
    return this.db
      .selectFrom('question_options')
      .select(['id', 'page_id', 'label'])
      .where('page_id', 'in', pageIds)
      .orderBy('position')
      .execute();
  }

  async isSaved(userId: string, lessonId: string): Promise<boolean> {
    const row = await this.db
      .selectFrom('saved_lessons')
      .select('lesson_id')
      .where('user_id', '=', userId)
      .where('lesson_id', '=', lessonId)
      .executeTakeFirst();
    return row !== undefined;
  }
}
