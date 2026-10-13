import { sql } from 'kysely';
import type { Database } from '../../db/kysely.js';

export class HomeRepository {
  constructor(private readonly db: Database) {}

  async user(userId: string) {
    return this.db
      .selectFrom('users')
      .select(['display_name', 'health_points_total'])
      .where('id', '=', userId)
      .executeTakeFirstOrThrow();
  }

  /** Distinct local calendar dates ('YYYY-MM-DD' in `timeZone`) with at least one completed attempt. */
  async completionDates(userId: string, timeZone: string): Promise<string[]> {
    const rows = await this.db
      .selectFrom('lesson_attempts')
      .select(sql<string>`to_char(completed_at at time zone ${timeZone}, 'YYYY-MM-DD')`.as('day'))
      .distinct()
      .where('user_id', '=', userId)
      .where('status', '=', 'completed')
      .execute();
    return rows.map((row) => row.day);
  }
}
