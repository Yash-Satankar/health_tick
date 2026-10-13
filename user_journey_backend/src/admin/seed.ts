/* eslint-disable @typescript-eslint/no-explicit-any -- the generic key-sync helper works across tables */
import { readFileSync } from 'node:fs';
import path from 'node:path';
import type { Kysely } from 'kysely';
import type { Database } from '../db/kysely.js';
import { assetUrl, readPngSize } from '../lib/assets.js';
import type { ContentBlock, ContentModel, ContentPage, ContentQuestion } from '../content/model.js';
import type { Manifest } from '../content/schema.js';

type AnyDb = Kysely<any>;
type Row = Record<string, unknown>;

export interface SeedStats {
  inserted: Record<string, number>;
  updated: Record<string, number>;
  deleted: Record<string, number>;
}

/** Stable JSON (sorted object keys) so jsonb values compare equal regardless of key order. */
function stable(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`;
  if (value && typeof value === 'object' && !(value instanceof Date)) {
    const entries = Object.entries(value as Row)
      .filter(([, v]) => v !== undefined)
      .sort(([a], [b]) => (a < b ? -1 : 1));
    return `{${entries.map(([k, v]) => `${JSON.stringify(k)}:${stable(v)}`).join(',')}}`;
  }
  return JSON.stringify(value ?? null);
}

/** Columns of `desired` whose value differs from `existing`. */
function changedColumns(existing: Row, desired: Row): Row {
  const patch: Row = {};
  for (const [column, value] of Object.entries(desired)) {
    if (stable(existing[column]) !== stable(value)) patch[column] = value;
  }
  return patch;
}

class Seeder {
  readonly stats: SeedStats = { inserted: {}, updated: {}, deleted: {} };

  constructor(private readonly db: AnyDb) {}

  private count(kind: keyof SeedStats, table: string, n: number) {
    if (n > 0) this.stats[kind][table] = (this.stats[kind][table] ?? 0) + n;
  }

  private async insert(table: string, rows: Row[], returning: string[] = ['id']): Promise<Row[]> {
    if (rows.length === 0) return [];
    this.count('inserted', table, rows.length);
    return this.db
      .insertInto(table)
      .values(rows as any)
      .returning(returning as any)
      .execute();
  }

  private async update(table: string, where: Row, patch: Row): Promise<void> {
    if (Object.keys(patch).length === 0) return;
    this.count('updated', table, 1);
    let query = this.db.updateTable(table).set(patch as any);
    for (const [column, value] of Object.entries(where))
      query = query.where(column as any, '=', value as any);
    await query.execute();
  }

  private async deleteWhere(table: string, column: string, values: unknown[]): Promise<void> {
    if (values.length === 0) return;
    this.count('deleted', table, values.length);
    await this.db
      .deleteFrom(table)
      .where(column as any, 'in', values as any)
      .execute();
  }

  /**
   * Upserts rows by `key`. Rows in `scope` (same parent) whose key is not in `rows` are "extras":
   * they are patched with `extraPatch(i)` (unpublished/deactivated and moved after the YAML rows), never deleted.
   * Only changed rows produce statements, so re-running with the same input issues no writes.
   */
  async syncKeyed(
    table: string,
    rows: (Row & { key: string })[],
    scope: { column: string; value: unknown } | 'all' | null,
    extraPatch: ((index: number) => Row) | null,
  ): Promise<Map<string, string>> {
    const keys = rows.map((row) => row.key);
    let query = this.db.selectFrom(table).selectAll();
    if (scope === 'all') {
      // every row is either desired or an extra
    } else if (scope) {
      query =
        keys.length > 0
          ? query.where((eb: any) => eb.or([eb('key', 'in', keys), eb(scope.column, '=', scope.value)]))
          : query.where(scope.column as any, '=', scope.value as any);
    } else if (keys.length > 0) {
      query = query.where('key' as any, 'in', keys as any);
    } else {
      return new Map();
    }
    const existing = (await query.execute()) as (Row & { id: string; key: string })[];
    const byKey = new Map(existing.map((row) => [row.key, row]));
    const ids = new Map<string, string>();

    const toInsert: Row[] = [];
    for (const row of rows) {
      const current = byKey.get(row.key);
      if (!current) toInsert.push(row);
      else {
        ids.set(row.key, current.id);
        await this.update(table, { id: current.id }, changedColumns(current, row));
      }
    }
    for (const inserted of await this.insert(table, toInsert, ['id', 'key'])) {
      ids.set(inserted.key as string, inserted.id as string);
    }
    if (extraPatch) {
      const desired = new Set(keys);
      const extras = existing
        .filter((row) => !desired.has(row.key))
        .sort((a, b) => Number(a.position ?? 0) - Number(b.position ?? 0));
      for (const [i, extra] of extras.entries()) {
        await this.update(table, { id: extra.id }, changedColumns(extra, extraPatch(i)));
      }
    }
    return ids;
  }

  async syncAppCopy(locale: string, copy: { key: string; value: string }[]): Promise<void> {
    const existing = await this.db.selectFrom('app_copy').selectAll().where('locale', '=', locale).execute();
    const byKey = new Map(existing.map((row: Row) => [row.key as string, row]));
    const toInsert: Row[] = [];
    for (const { key, value } of copy) {
      const current = byKey.get(key);
      if (!current) toInsert.push({ key, locale, value });
      else await this.update('app_copy', { key, locale }, changedColumns(current, { value }));
    }
    await this.insert('app_copy', toInsert, ['key']);
  }

  /** Pages are identified by (lesson, position); a page whose type changed is replaced. */
  async syncPages(lessonId: string, pages: ContentPage[], assetIds: Map<string, string>): Promise<void> {
    const existing = (await this.db
      .selectFrom('lesson_pages')
      .selectAll()
      .where('lesson_id', '=', lessonId)
      .execute()) as (Row & { id: string; position: number; page_type: string })[];
    const byPosition = new Map(existing.map((page) => [page.position, page]));

    const stale = existing.filter(
      (page) => page.position >= pages.length || pages[page.position]?.type !== page.page_type,
    );
    await this.deleteWhere(
      'lesson_pages',
      'id',
      stale.map((page) => page.id),
    );
    const staleIds = new Set(stale.map((page) => page.id));

    for (const [position, page] of pages.entries()) {
      const current = byPosition.get(position);
      let pageId: string;
      if (current && !staleIds.has(current.id)) {
        pageId = current.id;
        await this.update('lesson_pages', { id: pageId }, changedColumns(current, { cta_label: page.cta }));
      } else {
        const [inserted] = await this.insert('lesson_pages', [
          { lesson_id: lessonId, position, page_type: page.type, cta_label: page.cta },
        ]);
        pageId = inserted!.id as string;
      }
      if (page.question) await this.syncQuestion(pageId, page.question);
      await this.syncBlocks(pageId, page.blocks, assetIds);
    }
  }

  private async syncQuestion(pageId: string, q: ContentQuestion): Promise<void> {
    const desired: Row = {
      response_type: q.responseType,
      is_graded: q.isGraded,
      min_selections: q.minSelections,
      max_selections: q.maxSelections,
      answer_key: q.answerKey,
      input_placeholder: q.inputPlaceholder,
      min_length: q.minLength,
      max_length: q.maxLength,
      validation_message: q.validationMessage,
      explanation: q.explanation,
    };
    const current = await this.db
      .selectFrom('page_questions')
      .selectAll()
      .where('page_id', '=', pageId)
      .executeTakeFirst();
    if (!current) await this.insert('page_questions', [{ page_id: pageId, ...desired }], ['page_id']);
    else await this.update('page_questions', { page_id: pageId }, changedColumns(current, desired));

    // Options are identified by position so their ids survive label edits (answers reference them).
    const options = (await this.db
      .selectFrom('question_options')
      .selectAll()
      .where('page_id', '=', pageId)
      .execute()) as (Row & { id: string; position: number })[];
    const byPosition = new Map(options.map((option) => [option.position, option]));
    await this.deleteWhere(
      'question_options',
      'id',
      options.filter((option) => option.position >= q.options.length).map((option) => option.id),
    );
    // Labels are unique per question: a swap between positions would collide, so clear changed labels first.
    const changed = q.options
      .map((option, position) => ({ option, current: byPosition.get(position), position }))
      .filter(({ option, current }) => current && current.label !== option.label);
    for (const { current } of changed) {
      await this.update('question_options', { id: current!.id }, { label: `__seed_tmp_${current!.id}` });
      current!.label = `__seed_tmp_${current!.id}`;
    }
    const toInsert: Row[] = [];
    for (const [position, option] of q.options.entries()) {
      const current = byPosition.get(position);
      const row = { label: option.label, is_correct: option.isCorrect };
      if (!current) toInsert.push({ page_id: pageId, position, ...row });
      else await this.update('question_options', { id: current.id }, changedColumns(current, row));
    }
    await this.insert('question_options', toInsert);
  }

  /** Blocks are compared as a whole tree per page; any difference replaces the page's blocks. */
  private async syncBlocks(
    pageId: string,
    blocks: ContentBlock[],
    assetIds: Map<string, string>,
  ): Promise<void> {
    const existing = (await this.db
      .selectFrom('page_blocks')
      .selectAll()
      .where('page_id', '=', pageId)
      .orderBy('position')
      .execute()) as (Row & { id: string; parent_block_id: string | null })[];
    const shape = (rows: Row[], parentId: string | null): unknown[] =>
      rows
        .filter((row) => row.parent_block_id === parentId)
        .map((row) => ({
          type: row.block_type,
          content: row.content,
          asset: row.media_asset_id,
          children: shape(rows, row.id as string),
        }));
    const desiredShape = (list: ContentBlock[]): unknown[] =>
      list.map((block) => ({
        type: block.type,
        content: block.content,
        asset: block.assetKey ? assetIds.get(block.assetKey)! : null,
        children: desiredShape(block.children),
      }));
    if (stable(shape(existing, null)) === stable(desiredShape(blocks))) return;

    await this.deleteWhere(
      'page_blocks',
      'id',
      existing.filter((row) => row.parent_block_id === null).map((row) => row.id),
    );
    const toRow = (block: ContentBlock, position: number, parentId: string | null): Row => ({
      page_id: pageId,
      parent_block_id: parentId,
      position,
      block_type: block.type,
      content: JSON.stringify(block.content),
      media_asset_id: block.assetKey ? assetIds.get(block.assetKey)! : null,
    });
    const parents = await this.insert(
      'page_blocks',
      blocks.map((block, position) => toRow(block, position, null)),
      ['id', 'position'],
    );
    const children: Row[] = [];
    for (const parent of parents) {
      const block = blocks[parent.position as number]!;
      block.children.forEach((child, position) => children.push(toRow(child, position, parent.id as string)));
    }
    await this.insert('page_blocks', children);
  }
}

function assetRows(manifest: Manifest, assetDir: string): (Row & { key: string })[] {
  return manifest.assets.map((asset) => {
    const filePath = path.join(assetDir, asset.file);
    // Width/height come from the actual file (Fluent replacements differ from the cropped originals).
    const size = asset.format === 'png' ? readPngSize(readFileSync(filePath)) : null;
    const manifestSize = asset as { width?: unknown; height?: unknown };
    return {
      key: asset.key,
      kind: asset.kind,
      format: asset.format,
      url: assetUrl(asset.file),
      width: size?.width ?? (typeof manifestSize.width === 'number' ? manifestSize.width : null),
      height: size?.height ?? (typeof manifestSize.height === 'number' ? manifestSize.height : null),
      alt_text: asset.alt_text,
    };
  });
}

export interface SeedOptions {
  assetDir: string;
  demoUserId: string;
}

/**
 * Upserts all content by key in ONE transaction (SPEC §7.6) and creates the demo user if missing.
 * Idempotent: a second run with the same input issues no write statements, so the content version
 * does not change either.
 */
export async function seedContent(
  db: Database,
  model: ContentModel,
  manifest: Manifest,
  options: SeedOptions,
): Promise<SeedStats> {
  return (db as unknown as AnyDb).transaction().execute(async (trx) => {
    const seeder = new Seeder(trx);
    const assetIds = await seeder.syncKeyed(
      'media_assets',
      assetRows(manifest, options.assetDir),
      null,
      null,
    );
    const asset = (key: string | null) => (key ? assetIds.get(key)! : null);

    await seeder.syncAppCopy(model.locale, model.appCopy);

    const reasonCount = model.feedbackReasons.length;
    await seeder.syncKeyed(
      'feedback_reasons',
      model.feedbackReasons.map((r, position) => ({
        key: r.key,
        label: r.label,
        requires_text: r.requiresText,
        position,
        is_active: true,
      })),
      'all',
      (i) => ({ is_active: false, position: reasonCount + i }),
    );
    await seeder.syncKeyed(
      'answer_feedback_messages',
      model.feedbackMessages.map((m) => ({
        key: m.key,
        outcome: m.outcome,
        headline: m.headline,
        illustration_asset_id: asset(m.assetKey),
        weight: m.weight,
        is_active: m.isActive,
      })),
      'all',
      () => ({ is_active: false }),
    );

    const statusIds = await seeder.syncKeyed(
      'journey_statuses',
      model.statuses.map((s, position) => ({
        key: s.key,
        title: s.title,
        position,
        card_background_color: s.cardBackgroundColor,
        card_shadow_color: s.cardShadowColor,
        card_text_color: s.cardTextColor,
        is_published: true,
      })),
      'all',
      (i) => ({ is_published: false, position: model.statuses.length + i }),
    );

    for (const status of model.statuses) {
      const statusId = statusIds.get(status.key)!;
      const levelIds = await seeder.syncKeyed(
        'journey_levels',
        status.levels.map((l, position) => ({
          key: l.key,
          status_id: statusId,
          label: l.label,
          title: l.title,
          position,
          illustration_asset_id: asset(l.illustrationKey),
          is_published: true,
        })),
        { column: 'status_id', value: statusId },
        (i) => ({ is_published: false, position: status.levels.length + i }),
      );
      for (const level of status.levels) {
        const levelId = levelIds.get(level.key)!;
        const nodeIds = await seeder.syncKeyed(
          'journey_nodes',
          level.nodes.map((n, position) => ({
            key: n.key,
            level_id: levelId,
            node_type: n.type,
            title: n.title,
            position,
            icon_asset_id: asset(n.iconKey),
            is_published: true,
          })),
          { column: 'level_id', value: levelId },
          (i) => ({ is_published: false, position: level.nodes.length + i }),
        );
        for (const node of level.nodes) {
          const nodeId = nodeIds.get(node.key)!;
          const lessonIds = await seeder.syncKeyed(
            'lessons',
            node.lessons.map((l, position) => ({
              key: l.key,
              node_id: nodeId,
              title: l.title,
              summary: l.summary,
              position,
              completion_headline: l.completionHeadline,
              completion_message: l.completionMessage,
              completion_asset_id: asset(l.completionAssetKey),
              is_published: true,
            })),
            { column: 'node_id', value: nodeId },
            (i) => ({ is_published: false, position: node.lessons.length + i }),
          );
          for (const lesson of node.lessons) {
            await seeder.syncPages(lessonIds.get(lesson.key)!, lesson.pages, assetIds);
          }
        }
      }
    }

    await trx
      .insertInto('users')
      .values({ id: options.demoUserId, display_name: model.demoUser.displayName })
      .onConflict((oc: any) => oc.column('id').doNothing())
      .execute();

    return seeder.stats;
  });
}
