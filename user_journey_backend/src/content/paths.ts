import path from 'node:path';
import { fileURLToPath } from 'node:url';
import type { ContentPaths } from './model.js';

const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');

/** Default locations of the seed content inside user_journey_backend/. */
export const DEFAULT_CONTENT_PATHS: ContentPaths = {
  contentFile: path.join(backendRoot, 'seed', 'journey_content.yaml'),
  manifestFile: path.join(backendRoot, 'seed', 'asset-manifest.json'),
  assetDir: path.join(backendRoot, 'static', 'assets'),
};
