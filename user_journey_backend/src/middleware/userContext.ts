import type { RequestHandler } from 'express';
import { z } from 'zod';
import type { Database } from '../db/kysely.js';
import { AppError } from '../lib/errors.js';

const uuid = z.uuid();

/**
 * Identifies the caller from `X-User-Id` (SPEC §6.1). Missing, malformed or unknown ids → 401 USER_NOT_IDENTIFIED.
 * There is no authentication by design (demo user).
 */
export function userContext(db: Database): RequestHandler {
  return async (req, _res, next) => {
    const header = req.get('x-user-id');
    if (!header || !uuid.safeParse(header).success) {
      throw AppError.userNotIdentified();
    }
    const user = await db.selectFrom('users').select('id').where('id', '=', header).executeTakeFirst();
    if (!user) throw AppError.userNotIdentified('Unknown user');
    req.user = { id: user.id };
    next();
  };
}
