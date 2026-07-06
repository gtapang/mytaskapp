/**
 * Domain types for Hermes Notes. Raw string values are stable identifiers
 * used in persistence and the markdown mirror; never rename without a
 * migration. (Ported from the original Swift core; same contract.)
 */

export type TaskStatus = 'open' | 'in_progress' | 'done' | 'dropped';

export const isTerminal = (s: TaskStatus): boolean => s === 'done' || s === 'dropped';

export type TaskPriority = 'none' | 'low' | 'medium' | 'high';

const PRIORITY_RANK: Record<TaskPriority, number> = { none: 0, low: 1, medium: 2, high: 3 };

export const priorityRank = (p: TaskPriority): number => PRIORITY_RANK[p];

/**
 * Eisenhower quadrant. `unassigned` keeps the matrix optional: tasks only
 * appear on the planning screen once the user places them.
 */
export type EisenhowerQuadrant =
  | 'urgent_important'
  | 'important_not_urgent'
  | 'urgent_not_important'
  | 'not_urgent_not_important'
  | 'unassigned';

/** The four plannable quadrants in canonical display order. */
export const QUADRANT_MATRIX: EisenhowerQuadrant[] = [
  'urgent_important',
  'important_not_urgent',
  'urgent_not_important',
  'not_urgent_not_important',
];

export const quadrantFromFlags = (urgent: boolean, important: boolean): EisenhowerQuadrant => {
  if (urgent && important) return 'urgent_important';
  if (!urgent && important) return 'important_not_urgent';
  if (urgent && !important) return 'urgent_not_important';
  return 'not_urgent_not_important';
};

export const quadrantShortName = (q: EisenhowerQuadrant): string => {
  switch (q) {
    case 'urgent_important': return 'Do first';
    case 'important_not_urgent': return 'Schedule';
    case 'urgent_not_important': return 'Delegate';
    case 'not_urgent_not_important': return 'Eliminate';
    case 'unassigned': return 'Unassigned';
  }
};

export type InboxSource = 'local_capture' | 'telegram';

/**
 * What an inbox item probably wants to become. Produced locally by the
 * intelligence layer (or left 'unknown'); always a suggestion, never an
 * automatic conversion.
 */
export type SuggestedItemKind = 'note' | 'task' | 'note_and_task' | 'reference' | 'unknown';

export type HermesContextKind = 'email' | 'calendar' | 'summary';

// ---------------------------------------------------------------------------
// Entities (dates are ISO-8601 strings so the store stays plain JSON)
// ---------------------------------------------------------------------------

export interface Note {
  id: string;
  title: string;
  markdown: string;
  createdAt: string;
  updatedAt: string;
  tags: string[];
  folder?: string;
  notebook?: string;
  project?: string;
  pinned: boolean;
  archived: boolean;
  reminderAt?: string;
}

export interface TaskItem {
  id: string;
  title: string;
  status: TaskStatus;
  priority: TaskPriority;
  quadrant: EisenhowerQuadrant;
  dueDate?: string;
  reminderAt?: string;
  noteId?: string;
  project?: string;
  tags: string[];
  createdAt: string;
  updatedAt: string;
}

export interface Project {
  id: string;
  name: string;
  details: string;
  active: boolean;
}

export interface InboxItem {
  id: string;
  source: InboxSource;
  /** Stable id from the source system (e.g. Telegram capture id), for dedupe. */
  sourceId?: string;
  rawContent: string;
  createdAt: string;
  processed: boolean;
  resultingNoteId?: string;
  resultingTaskId?: string;
  suggestedKind: SuggestedItemKind;
}

export interface HermesContextItem {
  /** Upsert key from Hermes. */
  sourceId: string;
  kind: HermesContextKind;
  title: string;
  summary: string;
  /** 0..1 inferred importance; Hermes combines rules and inference. */
  importance: number;
  /** Name of the deterministic rule that fired, if any (e.g. "vip-sender"). */
  ruleHit?: string;
  sourceMetadata: Record<string, string>;
  occursAt?: string;
  fetchedAt: string;
  dismissed: boolean;
  linkedNoteId?: string;
  linkedTaskId?: string;
}

export interface Settings {
  hermesBaseUrl: string;
  hermesToken: string;
  /** Root of the markdown mirror; defaults to ~/Desktop/M/HermesNotes. */
  mirrorDir: string;
  /** Local LLM (Ollama-compatible) endpoint; empty disables AI assists. */
  ollamaUrl: string;
  ollamaModel: string;
  /** Optional ICS calendar feed URLs shown on the Calendar screen. */
  icsFeeds: string[];
}

export interface AppData {
  notes: Note[];
  tasks: TaskItem[];
  projects: Project[];
  inbox: InboxItem[];
  hermesContext: HermesContextItem[];
  settings: Settings;
  lastHermesSyncAt?: string;
}

export const isDueOn = (task: TaskItem, dayISO: string): boolean =>
  !!task.dueDate && task.dueDate.slice(0, 10) === dayISO.slice(0, 10);

export const isOverdue = (task: TaskItem, nowISO: string): boolean =>
  !!task.dueDate && !isTerminal(task.status) && task.dueDate.slice(0, 10) < nowISO.slice(0, 10);
