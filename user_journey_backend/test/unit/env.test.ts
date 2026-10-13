import { describe, expect, it } from 'vitest';
import { EnvError, databaseName, parseEnv } from '../../src/config/env.js';
import { assertTestDatabaseUrl } from '../helpers/testDb.js';

const base = { DATABASE_URL: 'postgres://u:p@localhost:5433/healthtick_dev' };

describe('parseEnv', () => {
  it('applies defaults for optional variables', () => {
    const env = parseEnv(base);
    expect(env).toMatchObject({
      NODE_ENV: 'development',
      PORT: 3000,
      LOG_LEVEL: 'info',
      CORS_ORIGINS: ['*'],
      SSE_HEARTBEAT_MS: 25000,
      APP_TIMEZONE: 'Asia/Kolkata',
      DEMO_USER_ID: '00000000-0000-4000-8000-000000000001',
    });
  });

  it('coerces numbers and splits CORS origins', () => {
    const env = parseEnv({ ...base, PORT: '8080', CORS_ORIGINS: 'http://a.test, http://b.test' });
    expect(env.PORT).toBe(8080);
    expect(env.CORS_ORIGINS).toEqual(['http://a.test', 'http://b.test']);
  });

  it('reports every invalid variable at once', () => {
    try {
      parseEnv({ DATABASE_URL: 'mysql://x/y', PORT: 'abc', APP_TIMEZONE: 'Mars/Base', DEMO_USER_ID: 'nope' });
      expect.unreachable();
    } catch (error) {
      expect(error).toBeInstanceOf(EnvError);
      const names = (error as EnvError).issues.map((issue) => issue.split(':')[0]);
      expect(names).toEqual(expect.arrayContaining(['DATABASE_URL', 'PORT', 'APP_TIMEZONE', 'DEMO_USER_ID']));
    }
  });

  it('rejects a TEST_DATABASE_URL whose name does not end in _test', () => {
    expect(() => parseEnv({ ...base, TEST_DATABASE_URL: base.DATABASE_URL })).toThrow(EnvError);
    expect(
      parseEnv({ ...base, TEST_DATABASE_URL: 'postgres://u:p@h:1/x_test' }).TEST_DATABASE_URL,
    ).toBeDefined();
  });
});

describe('test database guard', () => {
  it('extracts the database name', () => {
    expect(databaseName('postgres://u:p@localhost:5433/healthtick_test?sslmode=disable')).toBe(
      'healthtick_test',
    );
  });

  it('refuses non-test databases and missing URLs', () => {
    expect(() => assertTestDatabaseUrl(undefined)).toThrow(/not set/);
    expect(() => assertTestDatabaseUrl('postgres://u:p@localhost:5433/healthtick_dev')).toThrow(
      /must end in _test/,
    );
    expect(assertTestDatabaseUrl('postgres://u:p@localhost:5433/healthtick_test')).toContain(
      'healthtick_test',
    );
  });
});
