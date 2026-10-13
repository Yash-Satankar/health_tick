import { describe, expect, it } from 'vitest';
import { extractTokens, validateMarkup } from '../../src/lib/markup.js';

describe('validateMarkup', () => {
  it.each([
    'plain text',
    '**bold** and *italic* and ==highlight==',
    'By **simply changing *how* we eat, we can**',
    '==**Keystone Habit #2 — Balancing Your Food Zones**==',
    '*(Like drinking water automatically reduces food cravings)*',
    'Hello {{user.name}}! Your goal: {{answer.big_goal}}',
    '{{ user.name }} with spaces inside the braces',
    'If you see more water, then you _.',
    '',
  ])('accepts %j', (text) => {
    expect(validateMarkup(text)).toEqual([]);
  });

  it.each([
    ['**unclosed bold', /unclosed "bold"/],
    ['*unclosed italic', /unclosed "italic"/],
    ['==unclosed highlight', /unclosed "highlight"/],
    ['**bold *italic** crossing*', /closes across/],
    ['==a **b== c**', /closes across/],
    ['{{user.email}}', /invalid token/],
    ['{{answer.Bad-Key}}', /invalid token/],
    ['{{user.name', /invalid token/],
    ['stray }} brace', /unmatched/],
  ])('rejects %j', (text, message) => {
    const issues = validateMarkup(text);
    expect(issues.length).toBeGreaterThan(0);
    expect(issues.map((issue) => issue.message).join('; ')).toMatch(message);
  });
});

describe('extractTokens', () => {
  it('returns user and answer tokens in order', () => {
    expect(extractTokens('{{user.name}} wrote {{answer.big_goal}} and {{bad}}')).toEqual([
      { kind: 'user.name' },
      { kind: 'answer', key: 'big_goal' },
    ]);
  });
});
