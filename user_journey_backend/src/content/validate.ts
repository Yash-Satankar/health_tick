import { existsSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { readPngSize } from '../lib/assets.js';
import { extractTokens, validateMarkup } from '../lib/markup.js';
import type { ContentBlock, ContentIssue, ContentModel, ContentPage, ContentQuestion } from './model.js';
import type { Manifest } from './schema.js';

/** UI assets the API exposes in /bootstrap; the app relies on them. */
export const REQUIRED_UI_ASSETS = ['locked_node', 'completion_medal'] as const;

function checkMarkup(text: string, path: string, issues: ContentIssue[]): void {
  for (const issue of validateMarkup(text)) {
    issues.push({ path, message: `markup: ${issue.message} at character ${issue.index}` });
  }
}

/** Every markup-bearing string of a block (text, list items, accordion title), including children. */
function blockTexts(block: ContentBlock): { text: string; path: string }[] {
  const texts: { text: string; path: string }[] = [];
  const { content } = block;
  if (typeof content.text === 'string') texts.push({ text: content.text, path: `${block.path}.text` });
  if (typeof content.title === 'string') texts.push({ text: content.title, path: `${block.path}.title` });
  if (Array.isArray(content.items)) {
    content.items.forEach((item, i) => {
      if (typeof item === 'string') texts.push({ text: item, path: `${block.path}.items.${i}` });
    });
  }
  for (const child of block.children) texts.push(...blockTexts(child));
  return texts;
}

function pageTexts(page: ContentPage): { text: string; path: string }[] {
  const texts = page.blocks.flatMap(blockTexts);
  if (page.question?.explanation) {
    texts.push({ text: page.question.explanation, path: `${page.path}.question.explanation` });
  }
  return texts;
}

function blockAssets(block: ContentBlock): { key: string; path: string }[] {
  const own = block.assetKey ? [{ key: block.assetKey, path: `${block.path}.asset` }] : [];
  return [...own, ...block.children.flatMap(blockAssets)];
}

function checkQuestion(q: ContentQuestion, path: string, issues: ContentIssue[]): void {
  const correct = q.options.filter((option) => option.isCorrect).length;
  if (q.responseType === 'free_text') {
    if (q.options.length > 0) issues.push({ path, message: 'free-text questions must not have options' });
    if (q.isGraded) issues.push({ path, message: 'free-text questions cannot be graded' });
    if (q.minLength !== null && q.maxLength !== null && q.minLength > q.maxLength) {
      issues.push({ path, message: 'min_length must not exceed max_length' });
    }
    return;
  }
  if (q.options.length < 2) issues.push({ path, message: 'choice questions need at least 2 options' });
  if (q.answerKey) issues.push({ path, message: 'answer_key is only allowed on free-text questions' });
  const labels = new Set<string>();
  for (const option of q.options) {
    if (labels.has(option.label)) issues.push({ path, message: `duplicate option label "${option.label}"` });
    labels.add(option.label);
    if (option.label.length > 200) issues.push({ path, message: 'option labels are at most 200 characters' });
  }
  if (q.isGraded && q.responseType === 'single_choice' && correct !== 1) {
    issues.push({
      path,
      message: `graded single-choice questions need exactly one correct option (found ${correct})`,
    });
  }
  if (q.isGraded && q.responseType === 'multiple_choice' && correct < 1) {
    issues.push({ path, message: 'graded multiple-choice questions need at least one correct option' });
  }
  if (q.responseType === 'single_choice' && q.maxSelections !== 1) {
    issues.push({ path, message: 'single-choice questions allow exactly one selection' });
  }
  if (q.minSelections !== null && q.maxSelections !== null && q.minSelections > q.maxSelections) {
    issues.push({ path, message: 'min_selections must not exceed max_selections' });
  }
  if (q.minSelections !== null && q.minSelections > q.options.length) {
    issues.push({ path, message: 'min_selections exceeds the number of options' });
  }
}

function checkUniqueKeys(entries: { key: string; path: string }[], kind: string, issues: ContentIssue[]) {
  const seen = new Map<string, string>();
  for (const entry of entries) {
    const first = seen.get(entry.key);
    if (first)
      issues.push({ path: entry.path, message: `duplicate ${kind} key "${entry.key}" (first at ${first})` });
    else seen.set(entry.key, entry.path);
  }
}

/**
 * Content rules from SPEC §7.6 (`content:validate`), applied to the normalized model.
 * Returns every issue found; an empty array means the content is valid.
 */
export function validateModel(model: ContentModel, manifest: Manifest, assetDir: string): ContentIssue[] {
  const issues: ContentIssue[] = [];

  // ---- assets: manifest entries exist on disk; every reference is in the manifest ----
  const manifestKeys = new Set<string>();
  for (const [i, asset] of manifest.assets.entries()) {
    const assetPath = `manifest.assets.${i}`;
    if (manifestKeys.has(asset.key))
      issues.push({ path: assetPath, message: `duplicate asset key "${asset.key}"` });
    manifestKeys.add(asset.key);
    const filePath = path.join(assetDir, asset.file);
    if (!existsSync(filePath)) {
      issues.push({ path: assetPath, message: `asset file ${asset.file} does not exist in ${assetDir}` });
    } else if (asset.format === 'png' && !readPngSize(readFileSync(filePath))) {
      issues.push({ path: assetPath, message: `asset file ${asset.file} is not a valid PNG` });
    }
  }
  const references: { key: string; path: string }[] = [];
  for (const [name, key] of Object.entries(model.uiAssets))
    references.push({ key, path: `ui_assets.${name}` });
  for (const required of REQUIRED_UI_ASSETS) {
    if (!model.uiAssets[required])
      issues.push({ path: 'ui_assets', message: `missing ui asset "${required}"` });
  }
  model.feedbackMessages.forEach((m, i) =>
    references.push({ key: m.assetKey, path: `answer_feedback_messages.${i}.asset` }),
  );

  // `ui_asset.*` copy keys are reserved for the ui_assets map (see admin/seed.ts).
  for (const { key } of model.appCopy) {
    if (key.startsWith('ui_asset.')) {
      issues.push({ path: `app_copy.${key}`, message: 'the "ui_asset." prefix is reserved' });
    }
  }

  // ---- feedback pools ----
  for (const outcome of ['correct', 'incorrect'] as const) {
    if (!model.feedbackMessages.some((m) => m.outcome === outcome && m.isActive)) {
      issues.push({
        path: 'answer_feedback_messages',
        message: `no active feedback message for "${outcome}"`,
      });
    }
  }
  checkUniqueKeys(
    model.feedbackMessages.map((m, i) => ({ key: m.key, path: `answer_feedback_messages.${i}` })),
    'feedback message',
    issues,
  );
  checkUniqueKeys(
    model.feedbackReasons.map((r, i) => ({ key: r.key, path: `feedback_reasons.${i}` })),
    'feedback reason',
    issues,
  );

  // ---- journey tree ----
  const levels = model.statuses.flatMap((s) => s.levels);
  const nodes = levels.flatMap((l) => l.nodes);
  const lessons = nodes.flatMap((n) => n.lessons);
  checkUniqueKeys(model.statuses, 'status', issues);
  checkUniqueKeys(levels, 'level', issues);
  checkUniqueKeys(nodes, 'node', issues);
  checkUniqueKeys(lessons, 'lesson', issues);

  for (const level of levels) {
    if (level.illustrationKey)
      references.push({ key: level.illustrationKey, path: `${level.path}.illustration` });
  }
  for (const node of nodes) {
    references.push({ key: node.iconKey, path: `${node.path}.icon` });
    if (node.type === 'checkpoint' && node.lessons.length !== 1) {
      issues.push({
        path: node.path,
        message: `a checkpoint must have exactly one published lesson (found ${node.lessons.length})`,
      });
    }
  }

  for (const lesson of lessons) {
    if (lesson.completionAssetKey) {
      references.push({ key: lesson.completionAssetKey, path: `${lesson.path}.completion.asset` });
    }
    if (lesson.pages.length === 0)
      issues.push({ path: lesson.path, message: 'a lesson needs at least one page' });

    const answerKeysSoFar = new Set<string>();
    for (const page of lesson.pages) {
      // {{answer.key}} must refer to an answer_key on an EARLIER page of the same lesson.
      for (const { text, path: textPath } of pageTexts(page)) {
        checkMarkup(text, textPath, issues);
        for (const token of extractTokens(text)) {
          if (token.kind === 'answer' && !answerKeysSoFar.has(token.key)) {
            issues.push({
              path: textPath,
              message: `{{answer.${token.key}}} does not refer to an answer_key on an earlier page of this lesson`,
            });
          }
        }
      }
      for (const block of page.blocks) references.push(...blockAssets(block));
      if (page.question) {
        checkQuestion(page.question, `${page.path}.question`, issues);
        const key = page.question.answerKey;
        if (key) {
          if (answerKeysSoFar.has(key)) {
            issues.push({
              path: `${page.path}.question`,
              message: `duplicate answer_key "${key}" in lesson`,
            });
          }
          answerKeysSoFar.add(key);
        }
      }
    }
  }

  for (const ref of references) {
    if (!manifestKeys.has(ref.key)) issues.push({ path: ref.path, message: `unknown asset "${ref.key}"` });
  }
  return issues;
}
