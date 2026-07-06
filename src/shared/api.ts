import type { DayStartDigest } from '../core/dayStart';
import type {
  AppData,
  InboxItem,
  Note,
  Project,
  Settings,
  SuggestedItemKind,
  TaskItem,
  TaskPriority,
} from '../core/types';

/** A calendar event from an ICS feed, normalized for display. */
export interface CalendarEvent {
  id: string;
  title: string;
  startISO: string;
  endISO: string;
  allDay: boolean;
}

/** A task suggestion extracted from note text; the user confirms before anything becomes a real task. */
export interface ExtractedTaskSuggestion {
  title: string;
  priority: TaskPriority;
  /** Natural-language due hint as written in the note ("Friday", "next week"). */
  dueHint?: string;
}

export interface HermesStatus {
  configured: boolean;
  lastSyncAt?: string;
  lastError?: string;
  pendingOutbox: number;
}

/**
 * The typed IPC surface exposed to the renderer as `window.hermes`
 * (preload/contextBridge). One place; both sides import this.
 */
export interface HermesNotesApi {
  getData(): Promise<AppData>;

  saveNote(note: Note): Promise<void>;
  deleteNote(id: string): Promise<void>;
  saveTask(task: TaskItem): Promise<void>;
  deleteTask(id: string): Promise<void>;
  saveProject(project: Project): Promise<void>;
  addInbox(item: InboxItem): Promise<void>;
  updateInbox(item: InboxItem): Promise<void>;
  deleteInbox(id: string): Promise<void>;
  saveSettings(settings: Settings): Promise<void>;
  pickMirrorDir(): Promise<string | null>;

  hermesSync(): Promise<HermesStatus>;
  hermesStatus(): Promise<HermesStatus>;
  routeToWiki(noteId: string): Promise<void>;
  pushTelegram(text: string, replyToCaptureID?: string): Promise<void>;
  dismissContext(sourceId: string): Promise<void>;

  aiAvailable(): Promise<boolean>;
  aiSummarize(text: string): Promise<string>;
  aiSuggestTags(text: string, existing: string[]): Promise<string[]>;
  aiExtractTasks(text: string): Promise<ExtractedTaskSuggestion[]>;
  aiClassify(text: string): Promise<SuggestedItemKind>;
  aiDayStart(digest: DayStartDigest): Promise<string>;

  calendarEvents(dayISO: string): Promise<CalendarEvent[]>;

  /** Fired by the main process when the global quick-capture shortcut is hit. */
  onQuickCapture(callback: () => void): void;
}
