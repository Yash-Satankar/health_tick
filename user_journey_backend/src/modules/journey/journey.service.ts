import { toAssetDto, type AssetDto, type MediaAssetRow } from '../../lib/assets.js';
import { computeStates, type ProgressState, type ProgressStates, type RuleNode } from './journey.rules.js';
import type {
  JourneyRepository,
  LessonRow,
  LevelRow,
  NodeRow,
  PublishedTree,
  StatusRow,
} from './journey.repository.js';

export interface LessonContext {
  lesson: LessonRow;
  node: NodeRow;
  level: LevelRow;
  status: StatusRow;
  /** Index in global lesson order. */
  order: number;
}

/** The published journey plus one user's progress and derived states. Shared by journey, lessons, search, home. */
export interface JourneySnapshot {
  contentVersion: number;
  tree: PublishedTree;
  /** Nodes in global order with their lessons in order. */
  orderedNodes: (RuleNode & { row: NodeRow })[];
  lessons: Map<string, LessonContext>;
  states: ProgressStates;
  nodeCompletedAt: Map<string, Date>;
  lessonCompletedAt: Map<string, Date>;
  assets: Map<string, MediaAssetRow & { key: string }>;
}

export interface JourneyNodeDto {
  id: string;
  key: string;
  type: string;
  title: string;
  icon: AssetDto | null;
  state: ProgressState;
  completedAt: string | null;
  lessons: { id: string; title: string; state: ProgressState; completedAt: string | null }[];
}

export interface JourneyDto {
  contentVersion: number;
  statuses: {
    id: string;
    key: string;
    title: string;
    cardTheme: { backgroundColor: string; shadowColor: string; textColor: string };
    levels: {
      id: string;
      key: string;
      label: string;
      title: string;
      illustration: AssetDto | null;
      nodes: JourneyNodeDto[];
    }[];
  }[];
}

export class JourneyService {
  constructor(private readonly repo: JourneyRepository) {}

  async snapshot(userId: string): Promise<JourneySnapshot> {
    const [contentVersion, tree, nodeCompletedAt, lessonCompletedAt, assets] = await Promise.all([
      this.repo.contentVersion(),
      this.repo.publishedTree(),
      this.repo.nodeCompletions(userId),
      this.repo.lessonProgress(userId),
      this.repo.assets(),
    ]);
    const levelsById = new Map(tree.levels.map((level) => [level.id, level]));
    const statusesById = new Map(tree.statuses.map((status) => [status.id, status]));
    const lessonsByNode = new Map<string, LessonRow[]>();
    for (const lesson of tree.lessons) {
      const list = lessonsByNode.get(lesson.node_id) ?? [];
      list.push(lesson);
      lessonsByNode.set(lesson.node_id, list);
    }
    const orderedNodes = tree.nodes.map((row) => ({
      id: row.id,
      type: row.node_type,
      row,
      lessons: (lessonsByNode.get(row.id) ?? []).map((lesson) => ({ id: lesson.id })),
    }));
    const lessons = new Map<string, LessonContext>();
    let order = 0;
    for (const node of tree.nodes) {
      const level = levelsById.get(node.level_id)!;
      const status = statusesById.get(level.status_id)!;
      for (const lesson of lessonsByNode.get(node.id) ?? []) {
        lessons.set(lesson.id, { lesson, node, level, status, order: order++ });
      }
    }
    const states = computeStates(
      orderedNodes,
      new Set(nodeCompletedAt.keys()),
      new Set(lessonCompletedAt.keys()),
    );
    return {
      contentVersion,
      tree,
      orderedNodes,
      lessons,
      states,
      nodeCompletedAt,
      lessonCompletedAt,
      assets,
    };
  }

  /** Weak ETag `W/"c{contentVersion}-p{userProgressStamp}"` (SPEC §6.2). */
  async etag(userId: string): Promise<string> {
    const [version, stamp] = await Promise.all([this.repo.contentVersion(), this.repo.progressStamp(userId)]);
    return `W/"c${version}-p${stamp}"`;
  }

  async getJourney(userId: string): Promise<JourneyDto> {
    return toJourneyDto(await this.snapshot(userId));
  }
}

export function assetFor(snapshot: Pick<JourneySnapshot, 'assets'>, id: string | null): AssetDto | null {
  const row = id ? snapshot.assets.get(id) : undefined;
  return row ? toAssetDto(row) : null;
}

export function toJourneyDto(s: JourneySnapshot): JourneyDto {
  const iso = (date: Date | undefined) => (date ? date.toISOString() : null);
  return {
    contentVersion: s.contentVersion,
    statuses: s.tree.statuses.map((status) => ({
      id: status.id,
      key: status.key,
      title: status.title,
      cardTheme: {
        backgroundColor: status.card_background_color,
        shadowColor: status.card_shadow_color,
        textColor: status.card_text_color,
      },
      levels: s.tree.levels
        .filter((level) => level.status_id === status.id)
        .map((level) => ({
          id: level.id,
          key: level.key,
          label: level.label,
          title: level.title,
          illustration: assetFor(s, level.illustration_asset_id),
          nodes: s.orderedNodes
            .filter((node) => node.row.level_id === level.id)
            .map((node) => ({
              id: node.id,
              key: node.row.key,
              type: node.row.node_type,
              title: node.row.title,
              icon: assetFor(s, node.row.icon_asset_id),
              state: s.states.node.get(node.id)!,
              completedAt: iso(s.nodeCompletedAt.get(node.id)),
              lessons: node.lessons.map(({ id }) => ({
                id,
                title: s.lessons.get(id)!.lesson.title,
                state: s.states.lesson.get(id)!,
                completedAt: iso(s.lessonCompletedAt.get(id)),
              })),
            })),
        })),
    })),
  };
}
