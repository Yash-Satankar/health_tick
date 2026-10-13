import type { Database } from '../db/kysely.js';
import type { PlaceholderTemplate } from '../content/model.js';

export interface NodeCountResult {
  levelKey: string;
  publishedLessonNodes: number;
  created: string[];
  published: string[];
  unpublished: string[];
}

export class NodeCountError extends Error {}

export const MAX_DEMO_NODE_COUNT = 60;

/**
 * `demo:set-node-count` (SPEC §7.6): sets the number of published LESSON nodes in a level.
 * Extra nodes are unpublished (never deleted); missing ones are created as `demo_<level>_<i>` with one
 * placeholder lesson and a reused icon; the checkpoint stays last. Runs in one transaction so the app
 * receives a single real-time update.
 */
export async function setNodeCount(
  db: Database,
  levelKey: string,
  count: number,
  template: PlaceholderTemplate,
): Promise<NodeCountResult> {
  if (!Number.isInteger(count) || count < 0 || count > MAX_DEMO_NODE_COUNT) {
    throw new NodeCountError(`--count must be an integer between 0 and ${MAX_DEMO_NODE_COUNT}`);
  }
  return db.transaction().execute(async (trx) => {
    const level = await trx
      .selectFrom('journey_levels as l')
      .innerJoin('journey_statuses as s', 's.id', 'l.status_id')
      .select(['l.id', 'l.key', 'l.position', 's.position as status_position'])
      .where('l.key', '=', levelKey)
      .executeTakeFirst();
    if (!level) throw new NodeCountError(`Unknown level "${levelKey}"`);

    // Lock the level's nodes so concurrent runs serialize.
    const nodes = await trx
      .selectFrom('journey_nodes')
      .selectAll()
      .where('level_id', '=', level.id)
      .orderBy('position')
      .forUpdate()
      .execute();
    const lessonNodes = nodes.filter((node) => node.node_type !== 'checkpoint');
    const checkpoints = nodes.filter((node) => node.node_type === 'checkpoint');
    const result: NodeCountResult = {
      levelKey,
      publishedLessonNodes: count,
      created: [],
      published: [],
      unpublished: [],
    };

    // "Day N" numbering continues from the published lesson nodes of earlier levels.
    const earlier = await trx
      .selectFrom('journey_nodes as n')
      .innerJoin('journey_levels as l', 'l.id', 'n.level_id')
      .innerJoin('journey_statuses as s', 's.id', 'l.status_id')
      .select((eb) => eb.fn.countAll<number>().as('n'))
      .where('n.node_type', '=', 'lesson')
      .where('n.is_published', '=', true)
      .where('l.is_published', '=', true)
      .where('s.is_published', '=', true)
      .where((eb) =>
        eb.or([
          eb('s.position', '<', level.status_position),
          eb.and([eb('s.position', '=', level.status_position), eb('l.position', '<', level.position)]),
        ]),
      )
      .executeTakeFirstOrThrow();

    const iconAssetId =
      lessonNodes.at(-1)?.icon_asset_id ??
      nodes[0]?.icon_asset_id ??
      (await trx.selectFrom('media_assets').select('id').where('kind', '=', 'icon').executeTakeFirstOrThrow())
        .id;

    // Positions are rewritten below; start new rows far away to avoid transient collisions.
    let scratchPosition = 100_000 + nodes.length;
    for (let i = lessonNodes.length + 1; i <= count; i++) {
      const key = `demo_${levelKey}_${i}`;
      const node = await trx
        .insertInto('journey_nodes')
        .values({
          level_id: level.id,
          key,
          node_type: 'lesson',
          title: `Day ${Number(earlier.n) + i}`,
          position: scratchPosition++,
          icon_asset_id: iconAssetId,
          is_published: true,
        })
        .returningAll()
        .executeTakeFirstOrThrow();
      const lesson = await trx
        .insertInto('lessons')
        .values({
          node_id: node.id,
          key: `${key}_lesson`,
          title: `Demo lesson ${i}`,
          summary: 'Added by demo:set-node-count to demonstrate real-time journey updates.',
          position: 0,
          completion_headline: template.completion.headline,
          completion_message: template.completion.message,
        })
        .returning('id')
        .executeTakeFirstOrThrow();
      const page = await trx
        .insertInto('lesson_pages')
        .values({ lesson_id: lesson.id, position: 0, page_type: 'content', cta_label: template.cta })
        .returning('id')
        .executeTakeFirstOrThrow();
      await trx
        .insertInto('page_blocks')
        .values([
          {
            page_id: page.id,
            position: 0,
            block_type: 'heading',
            content: JSON.stringify({ text: `Demo lesson ${i}` }),
          },
          {
            page_id: page.id,
            position: 1,
            block_type: 'paragraph',
            content: JSON.stringify({
              text: 'This node was added while the app was open — the journey updated in real time.',
            }),
          },
        ])
        .execute();
      lessonNodes.push(node);
      result.created.push(key);
    }

    // First `count` lesson nodes are published, the rest unpublished; checkpoints go last.
    const ordered = [...lessonNodes, ...checkpoints];
    for (const [position, node] of ordered.entries()) {
      const shouldPublish = node.node_type === 'checkpoint' ? node.is_published : position < count;
      const patch: { position?: number; is_published?: boolean } = {};
      if (node.position !== position) patch.position = position;
      if (node.is_published !== shouldPublish) patch.is_published = shouldPublish;
      if (Object.keys(patch).length === 0) continue;
      await trx.updateTable('journey_nodes').set(patch).where('id', '=', node.id).execute();
      if (patch.is_published === true && !result.created.includes(node.key)) result.published.push(node.key);
      if (patch.is_published === false) result.unpublished.push(node.key);
    }
    return result;
  });
}
