// Copies SQL migration files next to the compiled migration index (tsc does not copy .sql files).
import { cpSync } from 'node:fs';

cpSync('src/db/migrations', 'dist/db/migrations', { recursive: true, filter: (src) => !src.endsWith('.ts') });
