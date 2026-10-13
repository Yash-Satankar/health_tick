import { describe, expect, it } from 'vitest';
import { addDays, computeStreak, localDate } from '../../src/lib/time.js';

const TZ = 'Asia/Kolkata'; // UTC+05:30

describe('localDate', () => {
  it('uses the app time zone, not UTC', () => {
    // 2026-10-12T19:00Z is 2026-10-13 00:30 in Kolkata
    expect(localDate(new Date('2026-10-12T19:00:00Z'), TZ)).toBe('2026-10-13');
    expect(localDate(new Date('2026-10-12T18:29:59Z'), TZ)).toBe('2026-10-12');
  });
  it('addDays crosses month boundaries', () => {
    expect(addDays('2026-10-01', -1)).toBe('2026-09-30');
    expect(addDays('2026-12-31', 1)).toBe('2027-01-01');
  });
});

describe('computeStreak', () => {
  const now = new Date('2026-10-13T06:00:00Z'); // 11:30 on 13 Oct in Kolkata

  it('counts consecutive days ending today', () => {
    expect(computeStreak(['2026-10-13', '2026-10-12', '2026-10-11'], now, TZ)).toBe(3);
  });

  it('counts consecutive days ending yesterday (today not done yet)', () => {
    expect(computeStreak(['2026-10-12', '2026-10-11'], now, TZ)).toBe(2);
  });

  it('is 0 when the last completion was before yesterday', () => {
    expect(computeStreak(['2026-10-11', '2026-10-10'], now, TZ)).toBe(0);
    expect(computeStreak([], now, TZ)).toBe(0);
  });

  it('stops at a gap', () => {
    expect(computeStreak(['2026-10-13', '2026-10-11'], now, TZ)).toBe(1);
  });

  it('uses the local date at the time-zone boundary', () => {
    // 00:10 on 14 Oct in Kolkata is still 13 Oct in UTC: "today" must be the 14th.
    const justAfterMidnight = new Date('2026-10-13T18:40:00Z');
    expect(computeStreak(['2026-10-14'], justAfterMidnight, TZ)).toBe(1);
    expect(computeStreak(['2026-10-13', '2026-10-12'], justAfterMidnight, TZ)).toBe(2); // ending yesterday
    // In UTC the same instant is still the 13th.
    expect(computeStreak(['2026-10-14'], justAfterMidnight, 'UTC')).toBe(0);
  });
});
