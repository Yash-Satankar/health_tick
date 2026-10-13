/**
 * npm run db:codegen → regenerates src/db/types.ts from the migrated DATABASE_URL using kysely-codegen.
 * int8 is mapped to number and date to string, matching the pg type parsers in src/db/kysely.ts.
 */
import { spawnSync } from 'node:child_process';
import { createRequire } from 'node:module';
import path from 'node:path';
import { loadEnvOrExit } from '../src/config/env.js';

const env = loadEnvOrExit();
const require = createRequire(import.meta.url);
const pkgDir = path.dirname(require.resolve('kysely-codegen/package.json'));
const bin = path.join(pkgDir, 'dist', 'cli', 'bin.js');

const args = [
  bin,
  '--dialect',
  'postgres',
  '--url',
  env.DATABASE_URL,
  '--out-file',
  'src/db/types.ts',
  '--exclude-pattern',
  'kysely_*',
  '--date-parser',
  'string',
  '--type-mapping',
  JSON.stringify({ int8: 'number' }),
  ...process.argv.slice(2),
];

const result = spawnSync(process.execPath, args, { stdio: 'inherit' });
process.exit(result.status ?? 1);
