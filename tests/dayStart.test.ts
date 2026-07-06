import { describe, expect, it } from 'vitest';
import { dayStartPrompt, fallbackSummary, type DayStartDigest } from '../src/core/dayStart';
import { makeSlug } from '../src/core/slug';
import { priorityRank, quadrantFromFlags } from '../src/core/types';

function makeDigest(tasks = 0, events = 0, hermes = 0, inbox = 0): DayStartDigest {
  return {
    dateISO: '2026-07-06',
    dueTasks: Array.from({ length: tasks }, (_, i) => ({
      title: `Task ${i}`,
      priority: i === 0 ? ('high' as const) : ('medium' as const),
      quadrant: 'urgent_important' as const,
      overdue: false,
    })),
    events: Array.from({ length: events }, (_, i) => ({
      title: `Event ${i}`,
      startISO: `2026-07-06T${String(9 + i).padStart(2, '0')}:00:00`,
      allDay: false,
    })),
    hermesHighlights: Array.from({ length: hermes }, (_, i) => ({
      kind: 'email' as const,
      title: `Email ${i}`,
    })),
    inboxCount: inbox,
  };
}

describe('fallbackSummary', () => {
  it('handles a clear day', () => {
    expect(fallbackSummary(makeDigest())).toBe('A clear day — nothing due and no events scheduled.');
  });

  it('leads with the first event, then mentions Hermes', () => {
    const summary = fallbackSummary(makeDigest(2, 1, 2));
    expect(summary).toContain('2 tasks due and 1 event today.');
    expect(summary).toContain('First up: Event 0');
    expect(summary).toContain('2 important items surfaced by Hermes.');
  });

  it('falls back to the top task when there are no timed events', () => {
    expect(fallbackSummary(makeDigest(3))).toContain('Top task: Task 0.');
  });
});

describe('dayStartPrompt', () => {
  it('stays compact and factual', () => {
    const prompt = dayStartPrompt(makeDigest(8, 7, 5, 3));
    expect(prompt).toContain('8 task(s) due today');
    // Caps keep the prompt calm and cheap: 5 tasks, 5 events, 3 highlights.
    expect(prompt.split('  - ').length - 1).toBe(5);
    expect(prompt.split('- Event:').length - 1).toBe(5);
    expect(prompt.split('- Important').length - 1).toBe(3);
    expect(prompt).toContain('3 unprocessed inbox item(s).');
  });
});

describe('core types', () => {
  it('maps urgency/importance flags to quadrants', () => {
    expect(quadrantFromFlags(true, true)).toBe('urgent_important');
    expect(quadrantFromFlags(false, true)).toBe('important_not_urgent');
    expect(quadrantFromFlags(true, false)).toBe('urgent_not_important');
    expect(quadrantFromFlags(false, false)).toBe('not_urgent_not_important');
  });

  it('orders priorities', () => {
    expect(priorityRank('none')).toBeLessThan(priorityRank('low'));
    expect(priorityRank('low')).toBeLessThan(priorityRank('medium'));
    expect(priorityRank('medium')).toBeLessThan(priorityRank('high'));
  });

  it('makes filesystem-safe slugs', () => {
    expect(makeSlug('Meeting: Q3 / planning!')).toBe('meeting-q3-planning');
    expect(makeSlug('   ')).toBe('untitled');
    expect(makeSlug('a'.repeat(100)).length).toBeLessThanOrEqual(60);
  });
});
