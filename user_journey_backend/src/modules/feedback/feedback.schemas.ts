import { z } from 'zod';

export const FeedbackBody = z.strictObject({
  reasonIds: z.array(z.uuid()).max(20).default([]),
  comment: z.string().max(1000).optional(),
  pageId: z.uuid().optional(),
});
export type FeedbackBody = z.infer<typeof FeedbackBody>;
