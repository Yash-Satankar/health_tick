import { pino, type Logger } from 'pino';

/**
 * Application logger. Request bodies, free-text answers and connection strings are never logged;
 * authorization/cookie headers are redacted defensively in case a header object is ever logged.
 */
export function createLogger(level: string): Logger {
  return pino({
    level,
    redact: {
      paths: ['req.headers.authorization', 'req.headers.cookie', 'headers.authorization', 'headers.cookie'],
      censor: '[redacted]',
    },
  });
}

export type { Logger };
