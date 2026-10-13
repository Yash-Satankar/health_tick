import type { Database } from '../../db/kysely.js';
import { toAssetDto, type AssetDto, type MediaAssetRow } from '../../lib/assets.js';
import { AppError } from '../../lib/errors.js';
import { weightedPick, type Rng } from '../../lib/rng.js';
import { JourneyRepository } from '../journey/journey.repository.js';
import type { JourneyService } from '../journey/journey.service.js';
import { requireOpenLesson } from '../lessons/lessons.service.js';
import { gradeAnswer, pointsForCompletion, type AnswerInput } from './attempts.grading.js';
import type { AttemptsRepository } from './attempts.repository.js';

export interface StartAttemptDto {
  attemptId: string;
  lessonId: string;
  startedAt: string;
  contentVersion: number;
}

export interface AnswerResultDto {
  pageId: string;
  isCorrect: boolean | null;
  feedback: {
    headline: string;
    illustration: AssetDto;
    correctAnswers: string[];
    explanation: string | null;
  } | null;
}

export interface CompletionDto {
  attemptId: string;
  lessonId: string;
  completedAt: string;
  firstCompletion: boolean;
  healthPointsEarned: number;
  healthPointsTotal: number;
  nodeCompleted: boolean;
  unlockedNodeId: string | null;
  completion: { headline: string; message: string; asset: AssetDto | null };
}

type NullableAsset = { [K in keyof MediaAssetRow]?: MediaAssetRow[K] | null };
const assetOrNull = (row: NullableAsset | undefined): AssetDto | null =>
  row?.url && row.format
    ? toAssetDto({
        url: row.url,
        width: row.width ?? null,
        height: row.height ?? null,
        alt_text: row.alt_text ?? '',
        format: row.format,
      })
    : null;

export class AttemptsService {
  constructor(
    private readonly db: Database,
    private readonly repo: AttemptsRepository,
    private readonly journey: JourneyService,
    private readonly rng: Rng,
  ) {}

  async start(userId: string, lessonId: string): Promise<StartAttemptDto> {
    const snapshot = await this.journey.snapshot(userId);
    requireOpenLesson(snapshot, lessonId);
    const attempt = await this.repo.insertAttempt(this.db, userId, lessonId, snapshot.contentVersion);
    return {
      attemptId: attempt.id,
      lessonId: attempt.lesson_id,
      startedAt: attempt.started_at.toISOString(),
      contentVersion: attempt.content_version,
    };
  }

  async answer(
    userId: string,
    attemptId: string,
    pageId: string,
    input: AnswerInput,
  ): Promise<AnswerResultDto> {
    return this.db.transaction().execute(async (trx) => {
      // Locking the attempt serializes answers with a concurrent complete/abandon.
      const attempt = await this.repo.lockAttempt(trx, attemptId, userId);
      if (!attempt) throw AppError.notFound('Attempt not found');
      if (attempt.status !== 'in_progress') throw AppError.attemptNotActive();
      const question = await this.repo.questionPage(trx, attempt.lesson_id, pageId);
      if (!question) throw AppError.notFound('Question page not found in this lesson');
      const options = await this.repo.optionsWithAnswers(trx, pageId);

      const graded = gradeAnswer(
        {
          responseType: question.response_type,
          isGraded: question.is_graded,
          minSelections: question.min_selections,
          maxSelections: question.max_selections,
          minLength: question.min_length,
          maxLength: question.max_length,
          options: options.map((option) => ({ id: option.id, isCorrect: option.is_correct })),
        },
        input,
      );

      let feedback: AnswerResultDto['feedback'] = null;
      let feedbackMessageId: string | null = null;
      if (graded.isCorrect !== null) {
        const pool = await this.repo.activeFeedbackMessages(trx, graded.isCorrect ? 'correct' : 'incorrect');
        const message = weightedPick(pool, this.rng);
        if (!message) throw new Error('No active feedback message for this outcome');
        feedbackMessageId = message.id;
        feedback = {
          headline: message.headline,
          illustration: toAssetDto(message),
          correctAnswers: options.filter((option) => option.is_correct).map((option) => option.label),
          explanation: question.explanation,
        };
      }

      await this.repo.upsertAnswer(trx, {
        attemptId,
        pageId,
        freeText: graded.kind === 'text' ? graded.text : null,
        isCorrect: graded.isCorrect,
        feedbackMessageId,
        optionIds: graded.kind === 'choice' ? graded.optionIds : [],
      });
      return { pageId, isCorrect: graded.isCorrect, feedback };
    });
  }

  /** SPEC §4.8 — one transaction, attempt row locked FOR UPDATE; idempotent for completed attempts. */
  async complete(userId: string, attemptId: string): Promise<CompletionDto> {
    return this.db.transaction().execute(async (trx) => {
      const attempt = await this.repo.lockAttempt(trx, attemptId, userId);
      if (!attempt) throw AppError.notFound('Attempt not found');
      if (attempt.status === 'abandoned') throw AppError.attemptNotActive('This attempt was abandoned');

      const lesson = await this.repo.lessonCompletion(trx, attempt.lesson_id);
      const medal = await this.repo.completionMedal(trx);
      const completion = {
        headline: lesson.completion_headline,
        message: lesson.completion_message,
        asset: assetOrNull(lesson) ?? assetOrNull(medal),
      };
      const nextNodeId = async (): Promise<string | null> => {
        const { nodes } = await new JourneyRepository(trx).publishedTree();
        const index = nodes.findIndex((node) => node.id === lesson.node_id);
        return index >= 0 ? (nodes[index + 1]?.id ?? null) : null;
      };

      if (attempt.status === 'completed') {
        // Idempotent replay: return the stored result, award nothing.
        const completedAt = attempt.completed_at!;
        const nodeDone = await this.repo.nodeCompletion(trx, userId, lesson.node_id);
        const nodeCompleted = nodeDone?.completed_at.getTime() === completedAt.getTime();
        let unlockedNodeId: string | null = null;
        if (nodeCompleted) {
          const next = await nextNodeId();
          const nextDone = next ? await this.repo.nodeCompletion(trx, userId, next) : undefined;
          if (next && (!nextDone || nextDone.completed_at.getTime() > completedAt.getTime()))
            unlockedNodeId = next;
        }
        return {
          attemptId,
          lessonId: attempt.lesson_id,
          completedAt: completedAt.toISOString(),
          firstCompletion: attempt.health_points_earned > 0,
          healthPointsEarned: attempt.health_points_earned,
          healthPointsTotal: await this.repo.userTotal(trx, userId),
          nodeCompleted,
          unlockedNodeId,
          completion,
        };
      }

      // Every current question page must be answered in this attempt.
      const [questionPages, answered] = await Promise.all([
        this.repo.questionPageIds(trx, attempt.lesson_id),
        this.repo.answeredPageIds(trx, attemptId),
      ]);
      const missing = questionPages.filter((id) => !answered.has(id));
      if (missing.length > 0) {
        const currentVersion = await this.repo.contentVersion(trx);
        if (attempt.content_version !== currentVersion) throw AppError.contentChanged();
        throw AppError.incompleteAttempt('Some questions have not been answered', {
          missingPageIds: missing,
        });
      }

      // Lock the user row: serializes point awards for this user.
      await this.repo.lockUser(trx, userId);
      const now = await this.repo.transactionNow(trx);
      const firstCompletion = !(await this.repo.hasProgress(trx, userId, attempt.lesson_id));
      const points = pointsForCompletion(firstCompletion, await this.repo.pageCount(trx, attempt.lesson_id));
      if (points > 0) await this.repo.awardPoints(trx, userId, attemptId, points);
      await this.repo.upsertProgress(trx, userId, attempt.lesson_id, now);

      // Node completion (SPEC §4.4) in the same transaction.
      let nodeCompleted = false;
      let unlockedNodeId: string | null = null;
      const alreadyDone = await this.repo.nodeCompletion(trx, userId, lesson.node_id);
      if (!alreadyDone && (await this.repo.incompleteLessonsInNode(trx, userId, lesson.node_id)) === 0) {
        await this.repo.insertNodeCompletion(trx, userId, lesson.node_id, now);
        nodeCompleted = true;
        const next = await nextNodeId();
        if (next && !(await this.repo.nodeCompletion(trx, userId, next))) unlockedNodeId = next;
      }

      await this.repo.markCompleted(trx, attemptId, now, points);
      return {
        attemptId,
        lessonId: attempt.lesson_id,
        completedAt: now.toISOString(),
        firstCompletion,
        healthPointsEarned: points,
        healthPointsTotal: await this.repo.userTotal(trx, userId),
        nodeCompleted,
        unlockedNodeId,
        completion,
      };
    });
  }

  /** SPEC §4.9: in_progress → abandoned; abandoned again is a no-op; completed → 409. */
  async abandon(userId: string, attemptId: string): Promise<void> {
    if ((await this.repo.markAbandoned(this.db, attemptId, userId)) > 0) return;
    const attempt = await this.repo.findAttempt(this.db, attemptId, userId);
    if (!attempt) throw AppError.notFound('Attempt not found');
    if (attempt.status === 'completed') throw AppError.attemptNotActive('This attempt is already completed');
  }
}
