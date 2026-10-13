import 'express';

declare module 'express-serve-static-core' {
  interface Request {
    /** Request id (echoed `X-Request-Id` or generated). Set by the requestId middleware. */
    id: string;
    /** Values parsed by the validate middleware. */
    valid: { params: unknown; query: unknown; body: unknown };
    /** The identified user. Set by the userContext middleware on /api/v1 routes. */
    user: { id: string };
  }
}
