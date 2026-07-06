/**
 * Minimal, tolerant ICS (RFC 5545) event extraction — just enough to show a
 * subscribed calendar feed on the Calendar screen: SUMMARY, DTSTART, DTEND,
 * and all-day detection. Anything it can't read, it skips.
 */

export interface IcsEvent {
  id: string;
  title: string;
  startISO: string;
  endISO: string;
  allDay: boolean;
}

export function parseIcs(text: string): IcsEvent[] {
  const lines = unfold(text);
  const events: IcsEvent[] = [];
  let current: Record<string, { params: string; value: string }> | null = null;

  for (const line of lines) {
    if (line === 'BEGIN:VEVENT') {
      current = {};
      continue;
    }
    if (line === 'END:VEVENT') {
      if (current) {
        const event = toEvent(current, events.length);
        if (event) events.push(event);
      }
      current = null;
      continue;
    }
    if (!current) continue;

    const colon = line.indexOf(':');
    if (colon <= 0) continue;
    const head = line.slice(0, colon);
    const value = line.slice(colon + 1);
    const semi = head.indexOf(';');
    const name = (semi === -1 ? head : head.slice(0, semi)).toUpperCase();
    const params = semi === -1 ? '' : head.slice(semi + 1).toUpperCase();
    current[name] = { params, value };
  }

  return events;
}

/** RFC 5545 line unfolding: continuation lines start with a space or tab. */
function unfold(text: string): string[] {
  const raw = text.split(/\r?\n/);
  const out: string[] = [];
  for (const line of raw) {
    if ((line.startsWith(' ') || line.startsWith('\t')) && out.length > 0) {
      out[out.length - 1] += line.slice(1);
    } else {
      out.push(line);
    }
  }
  return out;
}

function toEvent(
  fields: Record<string, { params: string; value: string }>,
  index: number
): IcsEvent | null {
  const start = fields['DTSTART'];
  if (!start) return null;

  const allDay = start.params.includes('VALUE=DATE') || /^\d{8}$/.test(start.value.trim());
  const startISO = parseIcsDate(start.value.trim());
  if (!startISO) return null;

  const end = fields['DTEND'];
  const endISO = end ? (parseIcsDate(end.value.trim()) ?? startISO) : startISO;

  const title = unescapeText(fields['SUMMARY']?.value ?? 'Untitled event');
  const id = fields['UID']?.value ?? `ics-${index}-${startISO}`;

  return { id, title, startISO, endISO, allDay };
}

/** Handles YYYYMMDD and YYYYMMDDTHHMMSS(Z) forms. Naive local times stay naive. */
export function parseIcsDate(value: string): string | null {
  const dateOnly = /^(\d{4})(\d{2})(\d{2})$/.exec(value);
  if (dateOnly) return `${dateOnly[1]}-${dateOnly[2]}-${dateOnly[3]}`;

  const dateTime = /^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})(Z?)$/.exec(value);
  if (dateTime) {
    const [, y, mo, d, h, mi, s, z] = dateTime;
    return `${y}-${mo}-${d}T${h}:${mi}:${s}${z === 'Z' ? 'Z' : ''}`;
  }
  return null;
}

function unescapeText(text: string): string {
  return text
    .replace(/\\n/gi, ' ')
    .replace(/\\,/g, ',')
    .replace(/\\;/g, ';')
    .replace(/\\\\/g, '\\');
}

/** Whether an event touches the given day (YYYY-MM-DD), in the event's own clock. */
export function eventOnDay(event: IcsEvent, dayISO: string): boolean {
  const day = dayISO.slice(0, 10);
  const startDay = event.startISO.slice(0, 10);
  if (event.allDay) {
    // DTEND for all-day events is exclusive per RFC 5545.
    const endDay = event.endISO.slice(0, 10);
    return startDay <= day && (endDay === startDay ? day === startDay : day < endDay);
  }
  return startDay === day;
}
