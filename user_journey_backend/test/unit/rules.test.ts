import { describe, expect, it } from 'vitest';
import { etagMatches } from '../../src/modules/journey/journey.controller.js';
import {
  computeStates,
  popoverAction,
  todayTaskLessonId,
  type RuleNode,
} from '../../src/modules/journey/journey.rules.js';

const nodes: RuleNode[] = [
  { id: 'n1', type: 'lesson', lessons: [{ id: 'a' }, { id: 'b' }, { id: 'c' }] },
  { id: 'n2', type: 'lesson', lessons: [{ id: 'd' }, { id: 'e' }] },
  { id: 'cp', type: 'checkpoint', lessons: [{ id: 'q' }] },
  { id: 'n3', type: 'lesson', lessons: [{ id: 'f' }] },
];

const states = (doneNodes: string[], doneLessons: string[]) =>
  computeStates(nodes, new Set(doneNodes), new Set(doneLessons));

describe('node and lesson states (SPEC 4.2, 4.3)', () => {
  it('fresh user: first node and its first lesson available, everything else locked', () => {
    const s = states([], []);
    expect([...s.node.values()]).toEqual(['available', 'locked', 'locked', 'locked']);
    expect(Object.fromEntries(s.lesson)).toEqual({
      a: 'available',
      b: 'locked',
      c: 'locked',
      d: 'locked',
      e: 'locked',
      q: 'locked',
      f: 'locked',
    });
  });

  it('within an available node, a lesson unlocks when the previous one is completed', () => {
    const s = states([], ['a']);
    expect(s.lesson.get('a')).toBe('completed');
    expect(s.lesson.get('b')).toBe('available');
    expect(s.lesson.get('c')).toBe('locked');
  });

  it('completing a node makes the next node available', () => {
    const s = states(['n1'], ['a', 'b', 'c']);
    expect(s.node.get('n1')).toBe('completed');
    expect(s.node.get('n2')).toBe('available');
    expect(s.lesson.get('d')).toBe('available');
    expect(s.node.get('cp')).toBe('locked');
  });

  it('a completed node stays completed and its new lessons are replayable (available)', () => {
    const s = states(['n1'], ['a', 'b']); // lesson c added after the node was completed
    expect(s.node.get('n1')).toBe('completed');
    expect(s.lesson.get('c')).toBe('available');
    expect(s.node.get('n2')).toBe('available');
  });

  it('a node is locked unless the node immediately before it is completed', () => {
    const s = states(['n1', 'cp'], ['a', 'b', 'c', 'q']); // n2 not completed
    expect(s.node.get('n2')).toBe('available');
    expect(s.node.get('cp')).toBe('completed');
    expect(s.node.get('n3')).toBe('available'); // previous (cp) completed
  });
});

describe('popover action (SPEC 4.6)', () => {
  it('start / continue / do it again / locked', () => {
    expect(popoverAction(nodes[0]!, states([], []))).toEqual({ action: 'start', lessonId: 'a' });
    expect(popoverAction(nodes[0]!, states([], ['a']))).toEqual({ action: 'continue', lessonId: 'b' });
    expect(popoverAction(nodes[0]!, states(['n1'], ['a', 'b', 'c']))).toEqual({
      action: 'do_it_again',
      lessonId: 'a',
    });
    expect(popoverAction(nodes[1]!, states([], []))).toBeNull();
  });
});

describe("today's task (SPEC 4.10)", () => {
  it('is the first available, not completed lesson in global order', () => {
    expect(todayTaskLessonId(nodes, states([], []))).toBe('a');
    expect(todayTaskLessonId(nodes, states(['n1'], ['a', 'b', 'c']))).toBe('d');
  });

  it('is null when everything is completed', () => {
    expect(
      todayTaskLessonId(nodes, states(['n1', 'n2', 'cp', 'n3'], ['a', 'b', 'c', 'd', 'e', 'q', 'f'])),
    ).toBeNull();
  });
});

describe('etagMatches', () => {
  it('compares weakly and supports lists and *', () => {
    expect(etagMatches('W/"c1-p0"', 'W/"c1-p0"')).toBe(true);
    expect(etagMatches('"c1-p0"', 'W/"c1-p0"')).toBe(true);
    expect(etagMatches('W/"x", W/"c1-p0"', 'W/"c1-p0"')).toBe(true);
    expect(etagMatches('*', 'W/"c1-p0"')).toBe(true);
    expect(etagMatches('W/"c2-p0"', 'W/"c1-p0"')).toBe(false);
    expect(etagMatches(undefined, 'W/"c1-p0"')).toBe(false);
  });
});
