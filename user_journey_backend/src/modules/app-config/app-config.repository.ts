import type { Database } from '../../db/kysely.js';

export class AppConfigRepository {
  constructor(private readonly db: Database) {}

  async contentVersion(): Promise<number> {
    return (await this.db.selectFrom('content_state').select('version').executeTakeFirstOrThrow()).version;
  }

  async user(userId: string) {
    return this.db
      .selectFrom('users')
      .select(['id', 'display_name', 'health_points_total'])
      .where('id', '=', userId)
      .executeTakeFirstOrThrow();
  }

  async copy(locale: string) {
    return this.db
      .selectFrom('app_copy')
      .select(['key', 'value'])
      .where('locale', '=', locale)
      .orderBy('key')
      .execute();
  }

  async assetsByKey(keys: string[]) {
    if (keys.length === 0) return [];
    return this.db
      .selectFrom('media_assets')
      .select(['key', 'url', 'width', 'height', 'alt_text', 'format'])
      .where('key', 'in', keys)
      .execute();
  }

  async activeFeedbackReasons() {
    return this.db
      .selectFrom('feedback_reasons')
      .select(['id', 'key', 'label', 'requires_text'])
      .where('is_active', '=', true)
      .orderBy('position')
      .execute();
  }
}
