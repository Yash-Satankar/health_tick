import { readFileSync } from 'node:fs';
import { parse as parseYaml } from 'yaml';
import { z } from 'zod';
import {
  AccordionBlockSchema,
  BlockSchema,
  ContentFileSchema,
  LeafBlockSchema,
  ManifestSchema,
  type ContentFile,
  type Manifest,
  type YamlLesson,
  type YamlPage,
  type YamlQuestion,
} from './schema.js';

/** A problem found while loading or validating content. `path` points into the YAML. */
export interface ContentIssue {
  path: string;
  message: string;
}

export type BlockType =
  | 'heading'
  | 'paragraph'
  | 'bulleted_list'
  | 'numbered_list'
  | 'image'
  | 'callout'
  | 'icon_heading'
  | 'accordion'
  | 'spacer';

export interface ContentBlock {
  path: string;
  type: BlockType;
  /** Stored in page_blocks.content (jsonb). */
  content: Record<string, unknown>;
  assetKey: string | null;
  children: ContentBlock[];
}

export interface ContentOption {
  label: string;
  isCorrect: boolean;
}

export interface ContentQuestion {
  responseType: 'single_choice' | 'multiple_choice' | 'free_text';
  isGraded: boolean;
  minSelections: number | null;
  maxSelections: number | null;
  answerKey: string | null;
  inputPlaceholder: string | null;
  minLength: number | null;
  maxLength: number | null;
  validationMessage: string | null;
  explanation: string | null;
  options: ContentOption[];
}

export interface ContentPage {
  path: string;
  type: 'content' | 'question';
  cta: string;
  blocks: ContentBlock[];
  question: ContentQuestion | null;
}

export interface ContentLesson {
  path: string;
  key: string;
  title: string;
  summary: string;
  isPlaceholder: boolean;
  completionHeadline: string;
  completionMessage: string;
  completionAssetKey: string | null;
  pages: ContentPage[];
}

export interface ContentNode {
  path: string;
  key: string;
  type: 'lesson' | 'checkpoint';
  title: string;
  iconKey: string;
  lessons: ContentLesson[];
}

export interface ContentLevel {
  path: string;
  key: string;
  label: string;
  title: string;
  illustrationKey: string | null;
  nodes: ContentNode[];
}

export interface ContentStatus {
  path: string;
  key: string;
  title: string;
  cardBackgroundColor: string;
  cardShadowColor: string;
  cardTextColor: string;
  levels: ContentLevel[];
}

export interface ContentModel {
  locale: string;
  demoUser: { id: string; displayName: string };
  appCopy: { key: string; value: string }[];
  feedbackMessages: {
    key: string;
    outcome: 'correct' | 'incorrect';
    assetKey: string;
    headline: string;
    weight: number;
    isActive: boolean;
  }[];
  feedbackReasons: { key: string; label: string; requiresText: boolean }[];
  uiAssets: Record<string, string>;
  placeholderTemplate: PlaceholderTemplate;
  statuses: ContentStatus[];
}

const zodIssues = (error: z.ZodError, prefix: string): ContentIssue[] =>
  error.issues.map((issue) => ({
    path: [prefix, ...issue.path.map(String)].filter(Boolean).join('.'),
    message: issue.message,
  }));

/** Parses YAML text with the content schema. Throws nothing; returns issues instead. */
export function parseContentFile(yamlText: string): { file: ContentFile | null; issues: ContentIssue[] } {
  let raw: unknown;
  try {
    raw = parseYaml(yamlText);
  } catch (error) {
    return { file: null, issues: [{ path: '', message: `YAML syntax error: ${(error as Error).message}` }] };
  }
  const result = ContentFileSchema.safeParse(raw);
  return result.success
    ? { file: result.data, issues: [] }
    : { file: null, issues: zodIssues(result.error, '') };
}

export function parseManifest(jsonText: string): { manifest: Manifest | null; issues: ContentIssue[] } {
  let raw: unknown;
  try {
    raw = JSON.parse(jsonText);
  } catch (error) {
    return {
      manifest: null,
      issues: [{ path: 'manifest', message: `JSON error: ${(error as Error).message}` }],
    };
  }
  const result = ManifestSchema.safeParse(raw);
  return result.success
    ? { manifest: result.data, issues: [] }
    : { manifest: null, issues: zodIssues(result.error, 'manifest') };
}

function buildBlock(
  raw: unknown,
  path: string,
  issues: ContentIssue[],
  asChild: boolean,
): ContentBlock | null {
  const type = (raw as { type?: unknown } | null)?.type;
  if (asChild && type === 'accordion') {
    issues.push({ path, message: 'accordion children must not be accordions (one level of nesting only)' });
    return null;
  }
  const parsed = (asChild ? LeafBlockSchema : BlockSchema).safeParse(raw);
  if (!parsed.success) {
    issues.push(...zodIssues(parsed.error, path));
    return null;
  }
  const block = parsed.data;
  switch (block.type) {
    case 'heading':
    case 'paragraph':
      return { path, type: block.type, content: { text: block.text }, assetKey: null, children: [] };
    case 'bulleted_list':
    case 'numbered_list':
      return { path, type: block.type, content: { items: block.items }, assetKey: null, children: [] };
    case 'image':
      return { path, type: 'image', content: {}, assetKey: block.asset, children: [] };
    case 'callout':
      return { path, type: 'callout', content: { text: block.text }, assetKey: block.asset, children: [] };
    case 'icon_heading':
      return {
        path,
        type: 'icon_heading',
        content: { text: block.text, color: block.color },
        assetKey: block.asset ?? null,
        children: [],
      };
    case 'spacer':
      return { path, type: 'spacer', content: { size: block.size }, assetKey: null, children: [] };
    case 'accordion': {
      const accordion = AccordionBlockSchema.parse(block);
      const children = accordion.children
        .map((child, i) => buildBlock(child, `${path}.children.${i}`, issues, true))
        .filter((child): child is ContentBlock => child !== null);
      return { path, type: 'accordion', content: { title: accordion.title }, assetKey: null, children };
    }
  }
}

function buildQuestion(q: YamlQuestion): ContentQuestion {
  const options = (q.options ?? []).map((option) =>
    typeof option === 'string'
      ? { label: option, isCorrect: false }
      : { label: option.label, isCorrect: option.correct ?? false },
  );
  return {
    responseType: q.response,
    isGraded: q.graded,
    minSelections: q.min_selections ?? null,
    maxSelections: q.response === 'single_choice' ? (q.max_selections ?? 1) : (q.max_selections ?? null),
    answerKey: q.answer_key ?? null,
    inputPlaceholder: q.input_placeholder ?? null,
    minLength: q.min_length ?? null,
    maxLength: q.max_length ?? null,
    validationMessage: q.validation_message ?? null,
    // An empty explanation means "no explanation" (the feedback card then omits it).
    explanation: q.explanation && q.explanation.trim().length > 0 ? q.explanation : null,
    options,
  };
}

function buildPage(page: YamlPage, path: string, issues: ContentIssue[]): ContentPage {
  const blocks = page.blocks
    .map((raw, i) => buildBlock(raw, `${path}.blocks.${i}`, issues, false))
    .filter((block): block is ContentBlock => block !== null);
  if (page.type === 'question' && !page.question) {
    issues.push({ path, message: 'a question page needs a `question`' });
  }
  if (page.type === 'content' && page.question) {
    issues.push({ path, message: 'a content page must not have a `question`' });
  }
  return {
    path,
    type: page.type,
    cta: page.cta,
    blocks,
    question: page.type === 'question' && page.question ? buildQuestion(page.question) : null,
  };
}

export interface PlaceholderTemplate {
  cta: string;
  completion: { headline: string; message: string; asset?: string | undefined };
}

/**
 * Placeholder lessons (provenance: placeholder, no pages) become one content page:
 * a heading with the lesson title and a paragraph with its summary (SPEC §7.6, YAML template).
 */
export function expandPlaceholder(
  lesson: YamlLesson,
  template: PlaceholderTemplate,
  path: string,
): ContentPage[] {
  return [
    {
      path: `${path}.pages.0`,
      type: 'content',
      cta: template.cta,
      blocks: [
        {
          path: `${path}.title`,
          type: 'heading',
          content: { text: lesson.title },
          assetKey: null,
          children: [],
        },
        {
          path: `${path}.summary`,
          type: 'paragraph',
          content: { text: lesson.summary ?? '' },
          assetKey: null,
          children: [],
        },
      ],
      question: null,
    },
  ];
}

export function buildLesson(
  lesson: YamlLesson,
  template: PlaceholderTemplate,
  path: string,
  issues: ContentIssue[],
): ContentLesson {
  const isPlaceholder = lesson.provenance === 'placeholder' && !lesson.pages;
  const pages = isPlaceholder
    ? expandPlaceholder(lesson, template, path)
    : (lesson.pages ?? []).map((page, i) => buildPage(page, `${path}.pages.${i}`, issues));
  if (isPlaceholder && !lesson.summary) {
    issues.push({ path, message: 'a placeholder lesson needs a `summary`' });
  }
  const completion = lesson.completion ?? template.completion;
  return {
    path,
    key: lesson.key,
    title: lesson.title,
    summary: lesson.summary ?? '',
    isPlaceholder,
    completionHeadline: completion.headline,
    completionMessage: completion.message,
    completionAssetKey: completion.asset ?? null,
    pages,
  };
}

/** Converts the parsed YAML into the normalized model the validator and seeder work on. */
export function buildModel(file: ContentFile): { model: ContentModel; issues: ContentIssue[] } {
  const issues: ContentIssue[] = [];
  const template = file.placeholder_template;
  const statuses: ContentStatus[] = file.statuses.map((status, si) => ({
    path: `statuses.${si}`,
    key: status.key,
    title: status.title,
    cardBackgroundColor: status.card_background_color,
    cardShadowColor: status.card_shadow_color,
    cardTextColor: status.card_text_color,
    levels: status.levels.map((level, li) => ({
      path: `statuses.${si}.levels.${li}`,
      key: level.key,
      label: level.label,
      title: level.title,
      illustrationKey: level.illustration ?? null,
      nodes: level.nodes.map((node, ni) => {
        const nodePath = `statuses.${si}.levels.${li}.nodes.${ni}`;
        return {
          path: nodePath,
          key: node.key,
          type: node.type,
          title: node.title,
          iconKey: node.icon,
          lessons: node.lessons.map((lesson, ki) =>
            buildLesson(lesson, template, `${nodePath}.lessons.${ki}`, issues),
          ),
        };
      }),
    })),
  }));

  return {
    issues,
    model: {
      locale: file.meta.locale,
      demoUser: { id: file.demo_user.id, displayName: file.demo_user.display_name },
      appCopy: Object.entries(file.app_copy).map(([key, value]) => ({ key, value })),
      feedbackMessages: file.answer_feedback_messages.map((m) => ({
        key: m.key,
        outcome: m.outcome,
        assetKey: m.asset,
        headline: m.headline,
        weight: m.weight ?? 1,
        isActive: m.active ?? true,
      })),
      feedbackReasons: file.feedback_reasons.map((r) => ({
        key: r.key,
        label: r.label,
        requiresText: r.requires_text ?? false,
      })),
      uiAssets: file.ui_assets,
      placeholderTemplate: template,
      statuses,
    },
  };
}

export interface ContentPaths {
  contentFile: string;
  manifestFile: string;
  assetDir: string;
}

export interface LoadedContent {
  model: ContentModel | null;
  manifest: Manifest | null;
  issues: ContentIssue[];
}

/** Reads and parses the content YAML and the asset manifest (no rule validation). */
export function loadContent(paths: ContentPaths): LoadedContent {
  const issues: ContentIssue[] = [];
  const { file, issues: fileIssues } = parseContentFile(readFileSync(paths.contentFile, 'utf8'));
  issues.push(...fileIssues);
  const { manifest, issues: manifestIssues } = parseManifest(readFileSync(paths.manifestFile, 'utf8'));
  issues.push(...manifestIssues);
  if (!file) return { model: null, manifest, issues };
  const { model, issues: modelIssues } = buildModel(file);
  issues.push(...modelIssues);
  return { model, manifest, issues };
}
