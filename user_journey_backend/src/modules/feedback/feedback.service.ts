import { AppError } from '../../lib/errors.js';
import type { JourneyService } from '../journey/journey.service.js';
import type { FeedbackRepository } from './feedback.repository.js';

export interface FeedbackInput {
  reasonIds: string[];
  comment?: string | undefined;
  pageId?: string | undefined;
}

export class FeedbackService {
  constructor(
    private readonly repo: FeedbackRepository,
    private readonly journey: JourneyService,
  ) {}

  /** FEEDBACK_INVALID when there is no reason and no comment, or a "requires text" reason (Others) has no comment. */
  async submit(userId: string, lessonId: string, input: FeedbackInput): Promise<{ feedbackId: string }> {
    const snapshot = await this.journey.snapshot(userId);
    if (!snapshot.lessons.has(lessonId)) throw AppError.notFound('Lesson not found');

    const reasonIds = [...new Set(input.reasonIds)];
    const comment = input.comment?.trim() ? input.comment.trim() : null;
    if (reasonIds.length === 0 && !comment) {
      throw AppError.feedbackInvalid('Choose at least one reason or write a comment');
    }
    const reasons = await this.repo.activeReasons(reasonIds);
    if (reasons.length !== reasonIds.length) throw AppError.feedbackInvalid('Unknown feedback reason');
    if (reasons.some((reason) => reason.requires_text) && !comment) {
      throw AppError.feedbackInvalid('Please describe the issue in the comment');
    }
    if (input.pageId && !(await this.repo.pageBelongsToLesson(input.pageId, lessonId))) {
      throw AppError.feedbackInvalid('The page does not belong to this lesson');
    }
    const feedbackId = await this.repo.insert({
      userId,
      lessonId,
      pageId: input.pageId ?? null,
      comment,
      reasonIds,
    });
    return { feedbackId };
  }
}
