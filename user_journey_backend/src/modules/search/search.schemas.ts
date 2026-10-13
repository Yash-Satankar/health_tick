import { z } from 'zod';

export const SearchQuery = z.strictObject({
  q: z.string().trim().min(2).max(100),
  sort: z.enum(['relevance', 'journey']).default('relevance'),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});
export type SearchQuery = z.infer<typeof SearchQuery>;
