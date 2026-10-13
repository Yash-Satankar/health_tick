/**
 * Pure progress rules (SPEC §4.2, §4.3, §4.6, §4.10). Inputs are the published nodes in global order
 * (status.position, level.position, node.position) with their published lessons in lesson order.
 */

export type ProgressState = 'completed' | 'available' | 'locked';

export interface RuleNode {
  id: string;
  type: string;
  lessons: { id: string }[];
}

export interface ProgressStates {
  node: Map<string, ProgressState>;
  lesson: Map<string, ProgressState>;
}

export function computeStates(
  nodes: readonly RuleNode[],
  completedNodeIds: ReadonlySet<string>,
  completedLessonIds: ReadonlySet<string>,
): ProgressStates {
  const node = new Map<string, ProgressState>();
  const lesson = new Map<string, ProgressState>();
  let previousCompleted = true; // the first node is available
  for (const n of nodes) {
    const nodeState: ProgressState = completedNodeIds.has(n.id)
      ? 'completed'
      : previousCompleted
        ? 'available'
        : 'locked';
    node.set(n.id, nodeState);
    previousCompleted = nodeState === 'completed';

    let previousLessonCompleted = true;
    for (const l of n.lessons) {
      const done = completedLessonIds.has(l.id);
      let state: ProgressState;
      if (done) state = 'completed';
      else if (nodeState === 'locked') state = 'locked';
      else if (nodeState === 'completed')
        state = 'available'; // every lesson of a finished node can be replayed
      else state = previousLessonCompleted ? 'available' : 'locked';
      lesson.set(l.id, state);
      previousLessonCompleted = done;
    }
  }
  return { node, lesson };
}

export type PopoverAction = 'do_it_again' | 'start' | 'continue';

/** Popover primary button (SPEC §4.6): which copy key to use and which lesson it opens. */
export function popoverAction(
  node: RuleNode,
  states: ProgressStates,
): { action: PopoverAction; lessonId: string | null } | null {
  const nodeState = states.node.get(node.id);
  if (!nodeState || nodeState === 'locked') return null;
  const first = node.lessons[0]?.id ?? null;
  if (nodeState === 'completed') return { action: 'do_it_again', lessonId: first };
  const anyDone = node.lessons.some((l) => states.lesson.get(l.id) === 'completed');
  if (!anyDone) return { action: 'start', lessonId: first };
  const next = node.lessons.find((l) => states.lesson.get(l.id) === 'available');
  return { action: 'continue', lessonId: next?.id ?? first };
}

/** Today's task: the first available, not completed lesson in global order (null if all done). */
export function todayTaskLessonId(nodes: readonly RuleNode[], states: ProgressStates): string | null {
  for (const n of nodes) {
    for (const l of n.lessons) {
      if (states.lesson.get(l.id) === 'available') return l.id;
    }
  }
  return null;
}
