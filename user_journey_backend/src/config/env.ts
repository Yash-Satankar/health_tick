import { existsSync } from 'node:fs';
import { z } from 'zod';

const postgresUrl = z
  .string()
  .regex(/^postgres(ql)?:\/\/.+\/[^/?]+/, 'must be a postgres:// URL that includes a database name');

/** Database name of a postgres connection URL (the path without the leading slash). */
export function databaseName(url: string): string {
  return decodeURIComponent(new URL(url).pathname.replace(/^\//, ''));
}

const isValidTimeZone = (tz: string): boolean => {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
};

export const EnvSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  DATABASE_URL: postgresUrl,
  TEST_DATABASE_URL: postgresUrl
    .refine((url) => databaseName(url).endsWith('_test'), 'database name must end in _test')
    .optional(),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  CORS_ORIGINS: z
    .string()
    .default('*')
    .transform((value) =>
      value
        .split(',')
        .map((origin) => origin.trim())
        .filter((origin) => origin.length > 0),
    ),
  SSE_HEARTBEAT_MS: z.coerce.number().int().min(1000).max(600_000).default(25_000),
  APP_TIMEZONE: z.string().refine(isValidTimeZone, 'must be a valid IANA time zone').default('Asia/Kolkata'),
  DEMO_USER_ID: z.uuid().default('00000000-0000-4000-8000-000000000001'),
});

export type Env = z.infer<typeof EnvSchema>;

export class EnvError extends Error {
  constructor(readonly issues: string[]) {
    super(`Invalid environment configuration:\n${issues.map((issue) => `  - ${issue}`).join('\n')}`);
    this.name = 'EnvError';
  }
}

/** Parses and validates environment variables. Throws `EnvError` listing every invalid variable. */
export function parseEnv(source: Record<string, string | undefined>): Env {
  const result = EnvSchema.safeParse(source);
  if (!result.success) {
    throw new EnvError(result.error.issues.map((issue) => `${issue.path.join('.')}: ${issue.message}`));
  }
  return result.data;
}

/** Loads `.env` from the working directory (if present) without overriding variables already set. */
export function loadDotEnv(file = '.env'): void {
  if (existsSync(file)) process.loadEnvFile(file);
}

/** Loads `.env`, validates `process.env`, and exits the process with a clear message if it is invalid. */
export function loadEnvOrExit(): Env {
  loadDotEnv();
  try {
    return parseEnv(process.env);
  } catch (error) {
    if (error instanceof EnvError) {
      console.error(error.message);
      process.exit(1);
    }
    throw error;
  }
}
