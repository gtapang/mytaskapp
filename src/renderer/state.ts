import { createContext, useContext } from 'react';
import type { AppData, Note, TaskItem } from '../core/types';
import type { HermesNotesApi } from '../shared/api';

declare global {
  interface Window {
    hermes: HermesNotesApi;
  }
}

export const api: HermesNotesApi = window.hermes;

export type Screen = 'today' | 'notes' | 'calendar' | 'tasks' | 'eisenhower' | 'inbox';

export interface AppState {
  data: AppData;
  /** Re-fetch app data from the main process after a mutation. */
  refresh: () => Promise<void>;
  screen: Screen;
  setScreen: (screen: Screen) => void;
  openNote: (id: string | null) => void;
  openNoteId: string | null;
  setSettingsOpen: (open: boolean) => void;
  setCaptureOpen: (open: boolean) => void;
}

export const AppContext = createContext<AppState | null>(null);

export function useApp(): AppState {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error('AppContext missing');
  return ctx;
}

// --- small helpers shared across screens -----------------------------------

export const nowISO = () => new Date().toISOString();

export const todayISO = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

export const uuid = () => crypto.randomUUID();

export function newNote(partial: Partial<Note> = {}): Note {
  const ts = nowISO();
  return {
    id: uuid(),
    title: '',
    markdown: '',
    createdAt: ts,
    updatedAt: ts,
    tags: [],
    pinned: false,
    archived: false,
    ...partial,
  };
}

export function newTask(title: string, partial: Partial<TaskItem> = {}): TaskItem {
  const ts = nowISO();
  return {
    id: uuid(),
    title,
    status: 'open',
    priority: 'none',
    quadrant: 'unassigned',
    tags: [],
    createdAt: ts,
    updatedAt: ts,
    ...partial,
  };
}

export const displayTitle = (note: Note) => (note.title.length > 0 ? note.title : 'Untitled');

export const relativeTime = (iso: string): string => {
  const delta = Date.now() - new Date(iso).getTime();
  const minutes = Math.round(delta / 60_000);
  if (minutes < 1) return 'just now';
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  if (days < 30) return `${days}d ago`;
  return new Date(iso).toLocaleDateString();
};

export const PRIORITY_COLOR: Record<string, string> = {
  none: 'transparent',
  low: '#5a8bbf',
  medium: '#c07f3a',
  high: '#b4544a',
};
