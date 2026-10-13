import { z } from 'zod';

export const AttemptParams = z.object({ attemptId: z.uuid() });
export type AttemptParams = z.infer<typeof AttemptParams>;

export const AnswerParams = z.object({ attemptId: z.uuid(), pageId: z.uuid() });
export type AnswerParams = z.infer<typeof AnswerParams>;

/** Exactly one of `optionIds` or `text` (SPEC §6.2); unknown fields are rejected. */
export const AnswerBody = z.union([
  z.strictObject({ optionIds: z.array(z.uuid()).max(50) }),
  z.strictObject({ text: z.string().max(4000) }),
]);
export type AnswerBody = z.infer<typeof AnswerBody>;
