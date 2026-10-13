import { z } from 'zod';

export const LessonParams = z.object({ lessonId: z.uuid() });
export type LessonParams = z.infer<typeof LessonParams>;
