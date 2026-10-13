/** npm run content:validate → checks seed/journey_content.yaml, the asset manifest and asset files. Exits 1 on failure. */
import { formatIssues, loadAndValidateContent } from '../src/content/load.js';
import { DEFAULT_CONTENT_PATHS } from '../src/content/paths.js';

const result = loadAndValidateContent(DEFAULT_CONTENT_PATHS);
if (!result.ok) {
  console.error(
    `Content validation failed with ${result.issues.length} issue(s):\n${formatIssues(result.issues)}`,
  );
  process.exit(1);
}
const lessons = result.model.statuses.flatMap((s) =>
  s.levels.flatMap((l) => l.nodes.flatMap((n) => n.lessons)),
);
const pages = lessons.reduce((sum, lesson) => sum + lesson.pages.length, 0);
console.log(
  `Content OK: ${result.model.statuses.length} statuses, ${lessons.length} lessons ` +
    `(${lessons.filter((l) => l.isPlaceholder).length} placeholders), ${pages} pages, ` +
    `${result.manifest.assets.length} assets.`,
);
