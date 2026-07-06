import type { HermesContextItem, TaskPriority, EisenhowerQuadrant } from './types';
import { priorityRank } from './types';

/**
 * Inputs for the Today screen's day-start synthesis: a compact, typed digest
 * of what the day holds. Fed either to the local LLM (as a prompt) or to
 * `fallbackSummary` when no model is configured. Pure logic, fully testable.
 */
export interface DayStartDigest {
  dateISO: string;
  dueTasks: Array<{
    title: string;
    priority: TaskPriority;
    quadrant: EisenhowerQuadrant;
    overdue: boolean;
  }>;
  events: Array<{ title: string; startISO: string; allDay: boolean }>;
  hermesHighlights: Array<Pick<HermesContextItem, 'kind' | 'title'>>;
  inboxCount: number;
}

/**
 * Prompt handed to the local model. Kept short and factual — the model's job
 * is a two-sentence calm briefing, not analysis.
 */
export function dayStartPrompt(digest: DayStartDigest): string {
  const lines = ['Write a calm two-sentence morning briefing from these facts:'];
  if (digest.dueTasks.length === 0) {
    lines.push('- No tasks due today.');
  } else {
    const overdue = digest.dueTasks.filter((t) => t.overdue).length;
    lines.push(
      `- ${digest.dueTasks.length} task(s) due today${overdue > 0 ? `, ${overdue} overdue` : ''}.`
    );
    for (const task of digest.dueTasks.slice(0, 5)) {
      lines.push(`  - ${task.title} [${task.priority}]`);
    }
  }
  for (const event of digest.events.slice(0, 5)) {
    const time = event.allDay ? 'all day' : timeString(event.startISO);
    lines.push(`- Event: ${event.title} (${time})`);
  }
  for (const item of digest.hermesHighlights.slice(0, 3)) {
    lines.push(`- Important ${item.kind}: ${item.title}`);
  }
  if (digest.inboxCount > 0) {
    lines.push(`- ${digest.inboxCount} unprocessed inbox item(s).`);
  }
  return lines.join('\n');
}

/**
 * Deterministic rule-based briefing used when no local model is configured.
 * Same calm register, no intelligence required.
 */
export function fallbackSummary(digest: DayStartDigest): string {
  const parts: string[] = [];
  const tasks = digest.dueTasks.length;
  const events = digest.events.length;

  if (tasks === 0 && events === 0) {
    parts.push('A clear day — nothing due and no events scheduled.');
  } else if (events === 0) {
    parts.push(`${tasks} task${tasks === 1 ? '' : 's'} due today, with no events on the calendar.`);
  } else if (tasks === 0) {
    parts.push(`No tasks due today; ${events} event${events === 1 ? '' : 's'} on the calendar.`);
  } else {
    parts.push(`${tasks} task${tasks === 1 ? '' : 's'} due and ${events} event${events === 1 ? '' : 's'} today.`);
  }

  const timed = digest.events.filter((e) => !e.allDay);
  if (timed.length > 0) {
    const first = timed.reduce((a, b) => (a.startISO <= b.startISO ? a : b));
    parts.push(`First up: ${first.title} at ${timeString(first.startISO)}.`);
  } else if (digest.dueTasks.length > 0) {
    const top = digest.dueTasks.reduce((a, b) =>
      priorityRank(a.priority) >= priorityRank(b.priority) ? a : b
    );
    parts.push(`Top task: ${top.title}.`);
  }

  const highlights = digest.hermesHighlights.length;
  if (highlights > 0) {
    parts.push(`${highlights} important item${highlights === 1 ? '' : 's'} surfaced by Hermes.`);
  }

  return parts.join(' ');
}

function timeString(iso: string): string {
  const date = new Date(iso);
  return `${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;
}
