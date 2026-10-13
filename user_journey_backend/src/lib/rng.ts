/** Random source returning a float in [0, 1). Injected into services so tests are deterministic. */
export type Rng = () => number;

export const defaultRng: Rng = Math.random;

/** Picks one item with probability proportional to its weight. Returns undefined for an empty list. */
export function weightedPick<T extends { weight: number }>(items: readonly T[], rng: Rng): T | undefined {
  const total = items.reduce((sum, item) => sum + Math.max(0, item.weight), 0);
  if (items.length === 0 || total <= 0) return items[0];
  let roll = rng() * total;
  for (const item of items) {
    roll -= Math.max(0, item.weight);
    if (roll < 0) return item;
  }
  return items[items.length - 1];
}

/** A deterministic sequence of values, for tests. */
export function sequenceRng(values: number[]): Rng {
  let i = 0;
  return () => values[i++ % values.length]!;
}
