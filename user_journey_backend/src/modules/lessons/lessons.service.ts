import type { AssetDto } from '../../lib/assets.js';
import { AppError } from '../../lib/errors.js';
import {
  assetFor,
  type JourneyService,
  type JourneySnapshot,
  type LessonContext,
} from '../journey/journey.service.js';
import type { LessonsRepository } from './lessons.repository.js';

/**
 * Returns the lesson's context if it is visible to the user and not locked.
 * Unknown/unpublished → 404 NOT_FOUND, locked → 403 LESSON_LOCKED.
 */
export function requireOpenLesson(snapshot: JourneySnapshot, lessonId: string): LessonContext {
  const context = snapshot.lessons.get(lessonId);
  if (!context) throw AppError.notFound('Lesson not found');
  if (snapshot.states.lesson.get(lessonId) === 'locked') throw AppError.lessonLocked();
  return context;
}

export type BlockDto = { id: string; type: string; asset?: AssetDto | null; children?: BlockDto[] } & Record<
  string,
  unknown
>;

export interface QuestionDto {
  responseType: string;
  isGraded: boolean;
  minSelections: number | null;
  maxSelections: number | null;
  answerKey: string | null;
  inputPlaceholder: string | null;
  minLength: number | null;
  maxLength: number | null;
  validationMessage: string | null;
  options: { id: string; label: string }[];
}

export interface LessonDto {
  id: string;
  title: string;
  nodeId: string;
  nodeType: string;
  isSaved: boolean;
  pageCount: number;
  pages: {
    id: string;
    position: number;
    type: string;
    ctaLabel: string;
    blocks: BlockDto[];
    question: QuestionDto | null;
  }[];
}

export class LessonsService {
  constructor(
    private readonly repo: LessonsRepository,
    private readonly journey: JourneyService,
  ) {}

  async getLesson(userId: string, lessonId: string): Promise<LessonDto> {
    const snapshot = await this.journey.snapshot(userId);
    const context = requireOpenLesson(snapshot, lessonId);
    const pages = await this.repo.pages(lessonId);
    const pageIds = pages.map((page) => page.id);
    const [blocks, questions, options, isSaved] = await Promise.all([
      this.repo.blocks(pageIds),
      this.repo.questions(pageIds),
      this.repo.options(pageIds),
      this.repo.isSaved(userId, lessonId),
    ]);

    type BlockRow = (typeof blocks)[number];
    const toBlock = (row: BlockRow): BlockDto => {
      const content = (row.content ?? {}) as Record<string, unknown>;
      const dto: BlockDto = { ...content, id: row.id, type: row.block_type };
      if (row.media_asset_id || row.block_type === 'image' || row.block_type === 'callout') {
        dto.asset = assetFor(snapshot, row.media_asset_id);
      }
      if (row.block_type === 'accordion') {
        dto.children = blocks.filter((child) => child.parent_block_id === row.id).map(toBlock);
      }
      return dto;
    };
    const questionsByPage = new Map(questions.map((q) => [q.page_id, q]));

    return {
      id: lessonId,
      title: context.lesson.title,
      nodeId: context.node.id,
      nodeType: context.node.node_type,
      isSaved,
      pageCount: pages.length,
      pages: pages.map((page) => {
        const q = questionsByPage.get(page.id);
        return {
          id: page.id,
          position: page.position,
          type: page.page_type,
          ctaLabel: page.cta_label,
          blocks: blocks
            .filter((block) => block.page_id === page.id && block.parent_block_id === null)
            .map(toBlock),
          question:
            page.page_type === 'question' && q
              ? {
                  responseType: q.response_type,
                  isGraded: q.is_graded,
                  minSelections: q.min_selections,
                  maxSelections: q.max_selections,
                  answerKey: q.answer_key,
                  inputPlaceholder: q.input_placeholder,
                  minLength: q.min_length,
                  maxLength: q.max_length,
                  validationMessage: q.validation_message,
                  options: options
                    .filter((option) => option.page_id === page.id)
                    .map((option) => ({ id: option.id, label: option.label })),
                }
              : null,
        };
      }),
    };
  }
}
