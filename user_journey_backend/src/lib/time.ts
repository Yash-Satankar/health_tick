/** Calendar helpers in the app time zone (SPEC §4.10). Dates are 'YYYY-MM-DD' strings. */

export function localDate(instant: Date, timeZone: string): string {
  // en-CA formats as YYYY-MM-DD.
  return new Intl.DateTimeFormat('en-CA', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(instant);
}

export function addDays(date: string, days: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

/**
 * Number of consecutive calendar days with at least one completion, ending today or yesterday
 * (in the app time zone). 0 if neither today nor yesterday has a completion.
 */
export function computeStreak(activeDates: Iterable<string>, now: Date, timeZone: string): number {
  const days = new Set(activeDates);
  const today = localDate(now, timeZone);
  let cursor = days.has(today) ? today : addDays(today, -1);
  let streak = 0;
  while (days.has(cursor)) {
    streak += 1;
    cursor = addDays(cursor, -1);
  }
  return streak;
}
