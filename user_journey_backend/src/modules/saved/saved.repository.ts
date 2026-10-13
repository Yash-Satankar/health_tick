import type { Database } from '../../db/kysely.js';

export class SavedRepository {
  constructor(private readonly db: Database) {}

  async save(userId: string, lessonId: string): Promise<void> {
    await this.db
      .insertInto('saved_lessons')
      .values({ user_id: userId, lesson_id: lessonId })
      .onConflict((oc) => oc.columns(['user_id', 'lesson_id']).doNothing())
      .execute();
  }

  async unsave(userId: string, lessonId: string): Promise<void> {
    await this.db
      .deleteFrom('saved_lessons')
      .where('user_id', '=', userId)
      .where('lesson_id', '=', lessonId)
      .execute();
  }
}
