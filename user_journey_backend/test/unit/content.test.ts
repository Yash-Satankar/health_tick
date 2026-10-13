/* eslint-disable @typescript-eslint/no-explicit-any -- tests mutate untyped YAML fixtures */
import { describe, expect, it } from 'vitest';
import { stringify } from 'yaml';
import { buildModel, parseContentFile, type ContentModel } from '../../src/content/model.js';
import type { Manifest } from '../../src/content/schema.js';
import { validateModel } from '../../src/content/validate.js';
import { loadAndValidateContent } from '../../src/content/load.js';
import { DEFAULT_CONTENT_PATHS } from '../../src/content/paths.js';

/** Minimal valid content file; tests mutate a copy to break one rule at a time. */
function baseContent(): Record<string, unknown> {
  return {
    meta: { locale: 'en' },
    demo_user: { id: '00000000-0000-4000-8000-000000000001', display_name: 'Yash' },
    app_copy: { 'journey.title': 'Your Journey' },
    answer_feedback_messages: [
      { key: 'ok', outcome: 'correct', asset: 'icon', headline: 'Yes' },
      { key: 'no', outcome: 'incorrect', asset: 'icon', headline: 'No' },
    ],
    feedback_reasons: [{ key: 'others', label: 'Others', requires_text: true }],
    ui_assets: { locked_node: 'icon', completion_medal: 'icon' },
    placeholder_template: { cta: 'GOT IT', completion: { headline: 'Won', message: 'Done' } },
    statuses: [
      {
        key: 'beginner',
        title: 'Beginner',
        card_background_color: '#F9E4C9',
        card_shadow_color: '#DBC4A5',
        card_text_color: '#1C1C1C',
        levels: [
          {
            key: 'l1',
            label: 'LEVEL-1',
            title: 'Level',
            nodes: [
              {
                key: 'n1',
                type: 'lesson',
                title: 'Day 1',
                icon: 'icon',
                lessons: [
                  {
                    key: 'lesson_a',
                    title: 'Lesson A',
                    provenance: 'authored',
                    pages: [
                      {
                        type: 'question',
                        cta: 'NEXT',
                        blocks: [{ type: 'paragraph', text: 'Your goal?' }],
                        question: {
                          response: 'free_text',
                          answer_key: 'goal',
                          min_length: 1,
                          max_length: 300,
                        },
                      },
                      {
                        type: 'content',
                        cta: 'DONE',
                        blocks: [
                          { type: 'paragraph', text: 'Goal: {{answer.goal}}' },
                          {
                            type: 'accordion',
                            title: 'More',
                            children: [{ type: 'bulleted_list', items: ['a', 'b'] }],
                          },
                        ],
                      },
                    ],
                  },
                  {
                    key: 'placeholder_b',
                    title: 'Lesson B',
                    provenance: 'placeholder',
                    summary: 'Short summary.',
                  },
                ],
              },
              {
                key: 'cp',
                type: 'checkpoint',
                title: 'Checkpoint',
                icon: 'icon',
                lessons: [
                  {
                    key: 'quiz',
                    title: 'Quiz',
                    pages: [
                      {
                        type: 'question',
                        cta: 'NEXT',
                        question: {
                          response: 'single_choice',
                          graded: true,
                          options: ['Wrong', { label: 'Right', correct: true }],
                        },
                      },
                    ],
                  },
                ],
              },
            ],
          },
        ],
      },
    ],
  };
}

const manifest: Manifest = {
  assets: [{ key: 'icon', file: 'node_psychology.png', kind: 'icon', format: 'png', alt_text: 'icon' }],
};

function issuesFor(mutate: (content: any) => void): string[] {
  const content = baseContent();
  mutate(content);
  const { file, issues } = parseContentFile(stringify(content));
  if (!file) return issues.map((issue) => `${issue.path}: ${issue.message}`);
  const built = buildModel(file);
  return [...built.issues, ...validateModel(built.model, manifest, DEFAULT_CONTENT_PATHS.assetDir)].map(
    (issue) => `${issue.path}: ${issue.message}`,
  );
}

const lessonA = (c: any) => c.statuses[0].levels[0].nodes[0].lessons[0];
const quizQuestion = (c: any) => c.statuses[0].levels[0].nodes[1].lessons[0].pages[0].question;

describe('content validator', () => {
  it('accepts the minimal valid content', () => {
    expect(issuesFor(() => {})).toEqual([]);
  });

  it('accepts the real seed content (content:validate)', () => {
    const result = loadAndValidateContent(DEFAULT_CONTENT_PATHS);
    expect(result.ok ? [] : result.issues).toEqual([]);
  });

  it('requires a checkpoint to have exactly one lesson', () => {
    const issues = issuesFor((c) => {
      const node = c.statuses[0].levels[0].nodes[1];
      node.lessons.push({ ...node.lessons[0], key: 'quiz_2' });
    });
    expect(issues.join('\n')).toMatch(/checkpoint must have exactly one published lesson \(found 2\)/);
  });

  it('requires at least one page per lesson', () => {
    expect(issuesFor((c) => (lessonA(c).pages = [])).join('\n')).toMatch(/at least one page/);
  });

  it('requires 2+ options and exactly one correct option for graded single choice', () => {
    expect(issuesFor((c) => (quizQuestion(c).options = ['Only'])).join('\n')).toMatch(/at least 2 options/);
    expect(issuesFor((c) => (quizQuestion(c).options = ['A', 'B'])).join('\n')).toMatch(
      /exactly one correct/,
    );
    expect(
      issuesFor(
        (c) =>
          (quizQuestion(c).options = [
            { label: 'A', correct: true },
            { label: 'B', correct: true },
          ]),
      ).join('\n'),
    ).toMatch(/exactly one correct option \(found 2\)/);
  });

  it('requires a correct option for graded multiple choice', () => {
    const issues = issuesFor((c) =>
      Object.assign(quizQuestion(c), { response: 'multiple_choice', options: ['A', 'B'] }),
    );
    expect(issues.join('\n')).toMatch(/at least one correct option/);
  });

  it('forbids options on free-text questions', () => {
    const issues = issuesFor((c) => (lessonA(c).pages[0].question.options = ['x', 'y']));
    expect(issues.join('\n')).toMatch(/free-text questions must not have options/);
  });

  it('requires {{answer.key}} to refer to an earlier page of the same lesson', () => {
    const reversed = issuesFor((c) => lessonA(c).pages.reverse());
    expect(reversed.join('\n')).toMatch(/\{\{answer\.goal\}\} does not refer/);
    const unknown = issuesFor((c) => (lessonA(c).pages[1].blocks[0].text = '{{answer.nope}}'));
    expect(unknown.join('\n')).toMatch(/\{\{answer\.nope\}\}/);
  });

  it('rejects nested accordions and children on non-accordion blocks', () => {
    const nested = issuesFor(
      (c) => (lessonA(c).pages[1].blocks[1].children = [{ type: 'accordion', title: 'x', children: [] }]),
    );
    expect(nested.join('\n')).toMatch(/accordion children must not be accordions/);
    const stray = issuesFor(
      (c) => (lessonA(c).pages[1].blocks[0].children = [{ type: 'paragraph', text: 'x' }]),
    );
    expect(stray.join('\n')).toMatch(/children/);
  });

  it('rejects unbalanced markup', () => {
    const issues = issuesFor((c) => (lessonA(c).pages[1].blocks[1].children[0].items = ['**open']));
    expect(issues.join('\n')).toMatch(/markup: unclosed "bold"/);
  });

  it('rejects unknown assets and missing asset files', () => {
    expect(issuesFor((c) => (c.statuses[0].levels[0].nodes[0].icon = 'ghost')).join('\n')).toMatch(
      /unknown asset "ghost"/,
    );
    const { file } = parseContentFile(stringify(baseContent()));
    const built = buildModel(file!);
    const missing = validateModel(
      built.model,
      { assets: [{ key: 'icon', file: 'missing.png', kind: 'icon', format: 'png', alt_text: '' }] },
      DEFAULT_CONTENT_PATHS.assetDir,
    );
    expect(missing.map((issue) => issue.message).join('\n')).toMatch(/missing\.png does not exist/);
  });

  it('reports unknown keys (typos) and YAML errors', () => {
    expect(issuesFor((c) => (lessonA(c).titel = 'typo')).join('\n')).toMatch(/titel/);
    expect(parseContentFile('a: [unclosed').issues[0]?.message).toMatch(/YAML syntax error/);
  });
});

describe('placeholder expansion', () => {
  it('expands a placeholder lesson into one content page with heading + summary', () => {
    const { file } = parseContentFile(stringify(baseContent()));
    const { model } = buildModel(file!);
    const placeholder = (model as ContentModel).statuses[0]!.levels[0]!.nodes[0]!.lessons[1]!;
    expect(placeholder.isPlaceholder).toBe(true);
    expect(placeholder.completionHeadline).toBe('Won');
    expect(placeholder.completionMessage).toBe('Done');
    expect(placeholder.pages).toHaveLength(1);
    expect(placeholder.pages[0]).toMatchObject({
      type: 'content',
      cta: 'GOT IT',
      question: null,
      blocks: [
        { type: 'heading', content: { text: 'Lesson B' } },
        { type: 'paragraph', content: { text: 'Short summary.' } },
      ],
    });
  });

  it('normalizes plain-string options and single-choice max selections', () => {
    const { file } = parseContentFile(stringify(baseContent()));
    const { model } = buildModel(file!);
    const q = model.statuses[0]!.levels[0]!.nodes[1]!.lessons[0]!.pages[0]!.question!;
    expect(q.options).toEqual([
      { label: 'Wrong', isCorrect: false },
      { label: 'Right', isCorrect: true },
    ]);
    expect(q.maxSelections).toBe(1);
  });

  it('requires a summary for placeholders', () => {
    const issues = issuesFor((c) => delete c.statuses[0].levels[0].nodes[0].lessons[1].summary);
    expect(issues.join('\n')).toMatch(/placeholder lesson needs a `summary`/);
  });
});
