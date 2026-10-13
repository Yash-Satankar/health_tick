import { describe, expect, it } from 'vitest';
import { AppError } from '../../src/lib/errors.js';
import { sequenceRng, weightedPick } from '../../src/lib/rng.js';
import {
  gradeAnswer,
  pointsForCompletion,
  type GradingQuestion,
} from '../../src/modules/attempts/attempts.grading.js';

const single: GradingQuestion = {
  responseType: 'single_choice',
  isGraded: true,
  minSelections: null,
  maxSelections: 1,
  minLength: null,
  maxLength: null,
  options: [
    { id: 'a', isCorrect: false },
    { id: 'b', isCorrect: true },
    { id: 'c', isCorrect: false },
  ],
};
const multiple: GradingQuestion = {
  ...single,
  responseType: 'multiple_choice',
  maxSelections: null,
  options: [
    { id: 'a', isCorrect: true },
    { id: 'b', isCorrect: true },
    { id: 'c', isCorrect: false },
  ],
};
const freeText: GradingQuestion = {
  ...single,
  responseType: 'free_text',
  isGraded: false,
  options: [],
  minLength: 1,
  maxLength: 10,
};

const invalid = (fn: () => unknown) => {
  try {
    fn();
  } catch (error) {
    expect(error).toBeInstanceOf(AppError);
    expect((error as AppError).code).toBe('ANSWER_INVALID');
    return;
  }
  throw new Error('expected ANSWER_INVALID');
};

describe('grading: single choice', () => {
  it('is correct only for the correct option', () => {
    expect(gradeAnswer(single, { optionIds: ['b'] })).toEqual({
      kind: 'choice',
      optionIds: ['b'],
      isCorrect: true,
    });
    expect(gradeAnswer(single, { optionIds: ['a'] }).isCorrect).toBe(false);
  });
  it('requires exactly one known option and an option-id body', () => {
    invalid(() => gradeAnswer(single, { optionIds: [] }));
    invalid(() => gradeAnswer(single, { optionIds: ['a', 'b'] }));
    invalid(() => gradeAnswer(single, { optionIds: ['zzz'] }));
    invalid(() => gradeAnswer(single, { text: 'b' }));
  });
  it('counts duplicate ids once', () => {
    expect(gradeAnswer(single, { optionIds: ['b', 'b'] }).isCorrect).toBe(true);
  });
});

describe('grading: multiple choice', () => {
  it('is correct only when the selection exactly equals the correct set', () => {
    expect(gradeAnswer(multiple, { optionIds: ['b', 'a'] }).isCorrect).toBe(true);
    expect(gradeAnswer(multiple, { optionIds: ['a'] }).isCorrect).toBe(false);
    expect(gradeAnswer(multiple, { optionIds: ['a', 'b', 'c'] }).isCorrect).toBe(false);
  });
  it('enforces min (default 1) and max selections', () => {
    invalid(() => gradeAnswer(multiple, { optionIds: [] }));
    invalid(() => gradeAnswer({ ...multiple, maxSelections: 2 }, { optionIds: ['a', 'b', 'c'] }));
    invalid(() => gradeAnswer({ ...multiple, minSelections: 2 }, { optionIds: ['a'] }));
  });
  it('ungraded questions get isCorrect = null', () => {
    expect(gradeAnswer({ ...multiple, isGraded: false }, { optionIds: ['c'] }).isCorrect).toBeNull();
  });
});

describe('grading: free text', () => {
  it('trims and enforces min/max length', () => {
    expect(gradeAnswer(freeText, { text: '  walk  ' })).toEqual({
      kind: 'text',
      text: 'walk',
      isCorrect: null,
    });
    invalid(() => gradeAnswer(freeText, { text: '    ' }));
    invalid(() => gradeAnswer(freeText, { text: 'x'.repeat(11) }));
    invalid(() => gradeAnswer(freeText, { optionIds: ['a'] }));
  });
  it('defaults to 1..2000 characters', () => {
    const open = { ...freeText, minLength: null, maxLength: null };
    expect(gradeAnswer(open, { text: 'x'.repeat(2000) }).kind).toBe('text');
    invalid(() => gradeAnswer(open, { text: 'x'.repeat(2001) }));
    invalid(() => gradeAnswer(open, { text: '' }));
  });
});

describe('points rule', () => {
  it('first completion earns the number of published pages; replays earn 0', () => {
    expect(pointsForCompletion(true, 13)).toBe(13);
    expect(pointsForCompletion(false, 13)).toBe(0);
  });
});

describe('weightedPick (injectable RNG)', () => {
  const items = [
    { id: 'x', weight: 1 },
    { id: 'y', weight: 3 },
  ];
  it('selects proportionally to weight, deterministically for a given RNG', () => {
    expect(weightedPick(items, () => 0)?.id).toBe('x');
    expect(weightedPick(items, () => 0.24)?.id).toBe('x');
    expect(weightedPick(items, () => 0.26)?.id).toBe('y');
    expect(weightedPick(items, () => 0.999)?.id).toBe('y');
    const rng = sequenceRng([0.1, 0.9]);
    expect([weightedPick(items, rng)?.id, weightedPick(items, rng)?.id]).toEqual(['x', 'y']);
  });
  it('returns undefined for an empty pool', () => {
    expect(weightedPick([], () => 0.5)).toBeUndefined();
  });
});
