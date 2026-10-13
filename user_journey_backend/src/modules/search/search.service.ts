import type { ProgressState } from '../journey/journey.rules.js';
import type { JourneyService } from '../journey/journey.service.js';
import type { SearchRepository } from './search.repository.js';

export type SearchSort = 'relevance' | 'journey';

export interface SearchResultDto {
  lessonId: string;
  title: string;
  summary: string;
  nodeId: string;
  nodeTitle: string;
  levelLabel: string;
  statusTitle: string;
  state: ProgressState;
}

export class SearchService {
  constructor(
    private readonly repo: SearchRepository,
    private readonly journey: JourneyService,
  ) {}

  async search(
    userId: string,
    q: string,
    sort: SearchSort,
    limit: number,
  ): Promise<{ query: string; results: SearchResultDto[] }> {
    const [matches, snapshot] = await Promise.all([this.repo.match(q), this.journey.snapshot(userId)]);
    const rows = matches
      .map((match) => ({ match, context: snapshot.lessons.get(match.id) }))
      .filter((row): row is { match: typeof row.match; context: NonNullable<typeof row.context> } =>
        Boolean(row.context),
      );
    rows.sort((a, b) =>
      sort === 'journey'
        ? a.context.order - b.context.order
        : b.match.score - a.match.score || a.context.order - b.context.order,
    );
    return {
      query: q,
      results: rows.slice(0, limit).map(({ context }) => ({
        lessonId: context.lesson.id,
        title: context.lesson.title,
        summary: context.lesson.summary,
        nodeId: context.node.id,
        nodeTitle: context.node.title,
        levelLabel: context.level.label,
        statusTitle: context.status.title,
        state: snapshot.states.lesson.get(context.lesson.id)!,
      })),
    };
  }
}
