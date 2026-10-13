import { AppError } from '../../lib/errors.js';
import type { JourneyService } from '../journey/journey.service.js';
import type { SavedRepository } from './saved.repository.js';

export class SavedService {
  constructor(
    private readonly repo: SavedRepository,
    private readonly journey: JourneyService,
  ) {}

  /** Idempotent: saving twice or removing twice gives the same result. Unknown/unpublished lesson → 404. */
  async setSaved(
    userId: string,
    lessonId: string,
    saved: boolean,
  ): Promise<{ lessonId: string; isSaved: boolean }> {
    const snapshot = await this.journey.snapshot(userId);
    if (!snapshot.lessons.has(lessonId)) throw AppError.notFound('Lesson not found');
    if (saved) await this.repo.save(userId, lessonId);
    else await this.repo.unsave(userId, lessonId);
    return { lessonId, isSaved: saved };
  }
}
