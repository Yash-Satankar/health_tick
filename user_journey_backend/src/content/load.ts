import type { ContentIssue, ContentModel, ContentPaths } from './model.js';
import { loadContent } from './model.js';
import type { Manifest } from './schema.js';
import { validateModel } from './validate.js';

export type ValidatedContent =
  { ok: true; model: ContentModel; manifest: Manifest; issues: [] } | { ok: false; issues: ContentIssue[] };

/** Loads the YAML + manifest and applies every content rule. Used by `content:validate` and `db:seed`. */
export function loadAndValidateContent(paths: ContentPaths): ValidatedContent {
  const { model, manifest, issues } = loadContent(paths);
  if (!model || !manifest) return { ok: false, issues };
  const allIssues = [...issues, ...validateModel(model, manifest, paths.assetDir)];
  return allIssues.length === 0
    ? { ok: true, model, manifest, issues: [] }
    : { ok: false, issues: allIssues };
}

export function formatIssues(issues: ContentIssue[]): string {
  return issues.map((issue) => `  ✗ ${issue.path || '(root)'}: ${issue.message}`).join('\n');
}
