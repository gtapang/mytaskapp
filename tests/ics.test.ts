import { describe, expect, it } from 'vitest';
import { eventOnDay, parseIcs, parseIcsDate } from '../src/core/ics';

const SAMPLE = [
  'BEGIN:VCALENDAR',
  'VERSION:2.0',
  'BEGIN:VEVENT',
  'UID:evt-1',
  'SUMMARY:Faculty meeting\\, room 201',
  'DTSTART:20260706T090000Z',
  'DTEND:20260706T100000Z',
  'END:VEVENT',
  'BEGIN:VEVENT',
  'UID:evt-2',
  'SUMMARY:Conference — very long title that gets fold',
  ' ed onto a second line',
  'DTSTART;VALUE=DATE:20260706',
  'DTEND;VALUE=DATE:20260708',
  'END:VEVENT',
  'BEGIN:VEVENT',
  'SUMMARY:Broken event with no start',
  'END:VEVENT',
  'END:VCALENDAR',
].join('\r\n');

describe('parseIcs', () => {
  it('extracts timed and all-day events, skipping broken ones', () => {
    const events = parseIcs(SAMPLE);
    expect(events).toHaveLength(2);

    expect(events[0]).toEqual({
      id: 'evt-1',
      title: 'Faculty meeting, room 201',
      startISO: '2026-07-06T09:00:00Z',
      endISO: '2026-07-06T10:00:00Z',
      allDay: false,
    });

    expect(events[1].allDay).toBe(true);
    expect(events[1].title).toBe('Conference — very long title that gets folded onto a second line');
    expect(events[1].startISO).toBe('2026-07-06');
  });
});

describe('parseIcsDate', () => {
  it('handles date and date-time forms', () => {
    expect(parseIcsDate('20260706')).toBe('2026-07-06');
    expect(parseIcsDate('20260706T090000Z')).toBe('2026-07-06T09:00:00Z');
    expect(parseIcsDate('20260706T090000')).toBe('2026-07-06T09:00:00');
    expect(parseIcsDate('garbage')).toBeNull();
  });
});

describe('eventOnDay', () => {
  const events = parseIcs(SAMPLE);

  it('matches timed events on their start day only', () => {
    expect(eventOnDay(events[0], '2026-07-06')).toBe(true);
    expect(eventOnDay(events[0], '2026-07-07')).toBe(false);
  });

  it('spans all-day events with exclusive DTEND', () => {
    expect(eventOnDay(events[1], '2026-07-06')).toBe(true);
    expect(eventOnDay(events[1], '2026-07-07')).toBe(true);
    expect(eventOnDay(events[1], '2026-07-08')).toBe(false);
  });
});
