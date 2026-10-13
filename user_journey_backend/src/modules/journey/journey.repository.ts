import { sql } from 'kysely';
import type { Database } from '../../db/kysely.js';
import type { MediaAssetRow } from '../../lib/assets.js';

export interface StatusRow {
  id: string;
  key: string;
  title: string;
  card_background_color: string;
  card_shadow_color: string;
  card_text_color: string;
}
export interface LevelRow {
  id: string;
  status_id: string;
  key: string;
  label: string;
  title: string;
  illustration_asset_id: string | null;
}
export interface NodeRow {
  id: string;
  level_id: string;
  key: string;
  node_type: string;
  title: string;
  icon_asset_id: string;
}
export interface LessonRow {
  id: string;
  node_id: string;
  key: string;
  title: string;
  summary: string;
}

export interface PublishedTree {
  statuses: StatusRow[];
  levels: LevelRow[];
  nodes: NodeRow[];
  lessons: LessonRow[];
}

/** Queries for the published journey tree and a user's progress. Visibility: every ancestor must be published. */
export class JourneyRepository {
  constructor(private readonly db: Database) {}

  async contentVersion(): Promise<number> {
    const row = await this.db.selectFrom('content_state').select('version').executeTakeFirstOrThrow();
    return row.version;
  }

  /** All published rows, each list in global order. */
  async publishedTree(): Promise<PublishedTree> {
    const statuses = await this.db
      .selectFrom('journey_statuses')
      .select(['id', 'key', 'title', 'card_background_color', 'card_shadow_color', 'card_text_color'])
      .where('is_published', '=', true)
      .orderBy('position')
      .execute();
    const levels = await this.db
      .selectFrom('journey_levels as l')
      .innerJoin('journey_statuses as s', 's.id', 'l.status_id')
      .select(['l.id', 'l.status_id', 'l.key', 'l.label', 'l.title', 'l.illustration_asset_id'])
      .where('l.is_published', '=', true)
      .where('s.is_published', '=', true)
      .orderBy('s.position')
      .orderBy('l.position')
      .execute();
    const nodes = await this.db
      .selectFrom('journey_nodes as n')
      .innerJoin('journey_levels as l', 'l.id', 'n.level_id')
      .innerJoin('journey_statuses as s', 's.id', 'l.status_id')
      .select(['n.id', 'n.level_id', 'n.key', 'n.node_type', 'n.title', 'n.icon_asset_id'])
      .where('n.is_published', '=', true)
      .where('l.is_published', '=', true)
      .where('s.is_published', '=', true)
      .orderBy('s.position')
      .orderBy('l.position')
      .orderBy('n.position')
      .execute();
    const lessons = await this.db
      .selectFrom('lessons as le')
      .innerJoin('journey_nodes as n', 'n.id', 'le.node_id')
      .innerJoin('journey_levels as l', 'l.id', 'n.level_id')
      .innerJoin('journey_statuses as s', 's.id', 'l.status_id')
      .select(['le.id', 'le.node_id', 'le.key', 'le.title', 'le.summary'])
      .where('le.is_published', '=', true)
      .where('n.is_published', '=', true)
      .where('l.is_published', '=', true)
      .where('s.is_published', '=', true)
      .orderBy('s.position')
      .orderBy('l.position')
      .orderBy('n.position')
      .orderBy('le.position')
      .execute();
    return { statuses, levels, nodes, lessons };
  }

  async assets(): Promise<Map<string, MediaAssetRow & { key: string }>> {
    const rows = await this.db
      .selectFrom('media_assets')
      .select(['id', 'key', 'url', 'width', 'height', 'alt_text', 'format'])
      .execute();
    return new Map(rows.map((row) => [row.id, row]));
  }

  async nodeCompletions(userId: string): Promise<Map<string, Date>> {
    const rows = await this.db
      .selectFrom('user_node_completions')
      .select(['node_id', 'completed_at'])
      .where('user_id', '=', userId)
      .execute();
    return new Map(rows.map((row) => [row.node_id, row.completed_at]));
  }

  async lessonProgress(userId: string): Promise<Map<string, Date>> {
    const rows = await this.db
      .selectFrom('user_lesson_progress')
      .select(['lesson_id', 'first_completed_at'])
      .where('user_id', '=', userId)
      .execute();
    return new Map(rows.map((row) => [row.lesson_id, row.first_completed_at]));
  }

  /** Epoch ms of the user's latest completion (0 if none) — part of the journey ETag. */
  async progressStamp(userId: string): Promise<number> {
    const row = await this.db
      .selectFrom('user_lesson_progress')
      .select(sql<string | null>`(extract(epoch from max(last_completed_at)) * 1000)::bigint`.as('stamp'))
      .where('user_id', '=', userId)
      .executeTakeFirst();
    return row?.stamp ? Number(row.stamp) : 0;
  }
}
