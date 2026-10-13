import { AppError } from '../../lib/errors.js';

/** Grading rules (SPEC §4.7). Pure: no database access. */

export interface GradingQuestion {
  responseType: string;
  isGraded: boolean;
  minSelections: number | null;
  maxSelections: number | null;
  minLength: number | null;
  maxLength: number | null;
  options: { id: string; isCorrect: boolean }[];
}

export type AnswerInput = { optionIds: string[] } | { text: string };

export type GradedAnswer =
  | { kind: 'choice'; optionIds: string[]; isCorrect: boolean | null }
  | { kind: 'text'; text: string; isCorrect: null };

export const DEFAULT_MAX_TEXT_LENGTH = 2000;

export function gradeAnswer(q: GradingQuestion, input: AnswerInput): GradedAnswer {
  if (q.responseType === 'free_text') {
    if (!('text' in input)) throw AppError.answerInvalid('This question expects a text answer');
    const text = input.text.trim();
    const min = q.minLength ?? 1;
    const max = q.maxLength ?? DEFAULT_MAX_TEXT_LENGTH;
    const length = [...text].length;
    if (length < min || length > max) {
      throw AppError.answerInvalid(`The answer must be between ${min} and ${max} characters`, { min, max });
    }
    return { kind: 'text', text, isCorrect: null };
  }

  if (!('optionIds' in input)) throw AppError.answerInvalid('This question expects option ids');
  const selected = [...new Set(input.optionIds)];
  const known = new Set(q.options.map((option) => option.id));
  if (selected.some((id) => !known.has(id))) {
    throw AppError.answerInvalid('An option does not belong to this question');
  }
  if (q.responseType === 'single_choice') {
    if (selected.length !== 1) throw AppError.answerInvalid('Exactly one option must be selected');
  } else {
    const min = q.minSelections ?? 1;
    const max = q.maxSelections ?? Number.POSITIVE_INFINITY;
    if (selected.length < min || selected.length > max) {
      throw AppError.answerInvalid(
        `Select between ${min} and ${Number.isFinite(max) ? max : 'any number of'} options`,
        {
          min,
          max: Number.isFinite(max) ? max : null,
        },
      );
    }
  }
  if (!q.isGraded) return { kind: 'choice', optionIds: selected, isCorrect: null };
  // Correct only if the selected set exactly equals the set of correct options.
  const correct = new Set(q.options.filter((option) => option.isCorrect).map((option) => option.id));
  const isCorrect = selected.length === correct.size && selected.every((id) => correct.has(id));
  return { kind: 'choice', optionIds: selected, isCorrect };
}

/** Points rule (SPEC §4.8): first completion earns one point per published page; replays earn nothing. */
export function pointsForCompletion(firstCompletion: boolean, publishedPageCount: number): number {
  return firstCompletion ? publishedPageCount : 0;
}
