import { sql } from 'kysely';
import type { Database } from '../../db/kysely.js';

/** Escapes LIKE wildcards so user input is matched literally. */
export const escapeLike = (value: string) => value.replace(/[\\%_]/g, (c) => `\\${c}`);

export class SearchRepository {
  constructor(private readonly db: Database) {}

  /**
   * Published lessons matching `q` by full-text search OR trigram word similarity on the title OR a
   * substring of the title (partial words such as "procrast"). Score = ts_rank + word_similarity.
   * Visibility (every ancestor published) is enforced by the joins.
   */
  async match(q: string): Promise<{ id: string; score: number }[]> {
    const tsQuery = sql`websearch_to_tsquery('english', ${q})`;
    const rows = await this.db
      .selectFrom('lessons as le')
      .innerJoin('journey_nodes as n', 'n.id', 'le.node_id')
      .innerJoin('journey_levels as l', 'l.id', 'n.level_id')
      .innerJoin('journey_statuses as s', 's.id', 'l.status_id')
      .select([
        'le.id',
        sql<number>`ts_rank(le.search_vector, ${tsQuery}) + word_similarity(lower(${q}), lower(le.title))`.as(
          'score',
        ),
      ])
      .where('le.is_published', '=', true)
      .where('n.is_published', '=', true)
      .where('l.is_published', '=', true)
      .where('s.is_published', '=', true)
      .where((eb) =>
        eb.or([
          sql<boolean>`le.search_vector @@ ${tsQuery}`,
          sql<boolean>`word_similarity(lower(${q}), lower(le.title)) >= 0.5`,
          sql<boolean>`le.title ilike ${`%${escapeLike(q)}%`}`,
        ]),
      )
      .execute();
    return rows.map((row) => ({ id: row.id, score: Number(row.score) }));
  }
}
