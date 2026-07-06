import { app, BrowserWindow, dialog, globalShortcut, ipcMain } from 'electron';
import * as path from 'path';
import { eventOnDay, parseIcs, type IcsEvent } from '../core/ics';
import { MarkdownMirror } from '../core/mirror';
import type { AppData, InboxItem, Note, Project, Settings, TaskItem } from '../core/types';
import type { DayStartDigest } from '../core/dayStart';
import { HermesSyncService } from './hermesSync';
import { Intelligence } from './intelligence';
import { JsonStore } from './store';

let win: BrowserWindow | null = null;

const userData = () => app.getPath('userData');

const store = new JsonStore(path.join(app.getPath('appData'), 'hermes-notes', 'data.json'));
const hermes = new HermesSyncService(store, path.join(app.getPath('appData'), 'hermes-notes', 'outbox.json'));
const intelligence = new Intelligence(() => store.get().settings);

const mirror = () => new MarkdownMirror(store.get().settings.mirrorDir);

// Simple per-URL ICS cache so the month grid doesn't hammer feeds.
const icsCache = new Map<string, { fetchedAt: number; events: IcsEvent[] }>();
const ICS_TTL_MS = 10 * 60 * 1000;

async function icsEvents(dayISO: string): Promise<IcsEvent[]> {
  const feeds = store.get().settings.icsFeeds.filter((u) => u.length > 0);
  const all: IcsEvent[] = [];
  for (const url of feeds) {
    const cached = icsCache.get(url);
    if (cached && Date.now() - cached.fetchedAt < ICS_TTL_MS) {
      all.push(...cached.events);
      continue;
    }
    try {
      const response = await fetch(url, { signal: AbortSignal.timeout(15_000) });
      if (!response.ok) continue;
      const events = parseIcs(await response.text());
      icsCache.set(url, { fetchedAt: Date.now(), events });
      all.push(...events);
    } catch {
      // Feed unreachable: show what we have; calendar is never blocking.
      if (cached) all.push(...cached.events);
    }
  }
  return all
    .filter((e) => eventOnDay(e, dayISO))
    .sort((a, b) => (a.allDay === b.allDay ? a.startISO.localeCompare(b.startISO) : a.allDay ? -1 : 1));
}

function mirrorNote(note: Note): void {
  const linkedTaskIds = store
    .get()
    .tasks.filter((t) => t.noteId === note.id)
    .map((t) => t.id);
  try {
    mirror().write(note, linkedTaskIds);
  } catch {
    // The mirror is derived state; it heals on the next save.
  }
}

function registerIpc(): void {
  ipcMain.handle('data:get', (): AppData => store.get());

  ipcMain.handle('note:save', (_e, note: Note) => {
    store.update((data) => {
      const index = data.notes.findIndex((n) => n.id === note.id);
      if (index >= 0) data.notes[index] = note;
      else data.notes.push(note);
    });
    mirrorNote(note);
  });

  ipcMain.handle('note:delete', (_e, id: string) => {
    store.update((data) => {
      data.notes = data.notes.filter((n) => n.id !== id);
      for (const task of data.tasks) {
        if (task.noteId === id) task.noteId = undefined;
      }
    });
    try {
      mirror().delete(id);
    } catch {
      // best effort
    }
  });

  ipcMain.handle('task:save', (_e, task: TaskItem) => {
    store.update((data) => {
      const index = data.tasks.findIndex((t) => t.id === task.id);
      if (index >= 0) data.tasks[index] = task;
      else data.tasks.push(task);
    });
    // Task links live in the note's mirror front matter — refresh it.
    const note = store.get().notes.find((n) => n.id === task.noteId);
    if (note) mirrorNote(note);
  });

  ipcMain.handle('task:delete', (_e, id: string) => {
    store.update((data) => {
      data.tasks = data.tasks.filter((t) => t.id !== id);
    });
  });

  ipcMain.handle('project:save', (_e, project: Project) => {
    store.update((data) => {
      const index = data.projects.findIndex((p) => p.id === project.id);
      if (index >= 0) data.projects[index] = project;
      else data.projects.push(project);
    });
  });

  ipcMain.handle('inbox:add', (_e, item: InboxItem) => {
    store.update((data) => {
      data.inbox.push(item);
    });
  });

  ipcMain.handle('inbox:update', (_e, item: InboxItem) => {
    store.update((data) => {
      const index = data.inbox.findIndex((i) => i.id === item.id);
      if (index >= 0) data.inbox[index] = item;
    });
  });

  ipcMain.handle('inbox:delete', (_e, id: string) => {
    store.update((data) => {
      data.inbox = data.inbox.filter((i) => i.id !== id);
    });
  });

  ipcMain.handle('hermes:dismissContext', (_e, sourceId: string) => {
    store.update((data) => {
      const item = data.hermesContext.find((c) => c.sourceId === sourceId);
      if (item) item.dismissed = true;
    });
  });

  ipcMain.handle('settings:save', (_e, settings: Settings) => {
    store.update((data) => {
      data.settings = settings;
    });
    icsCache.clear();
  });

  ipcMain.handle('settings:pickMirrorDir', async () => {
    if (!win) return null;
    const result = await dialog.showOpenDialog(win, {
      properties: ['openDirectory', 'createDirectory'],
      title: 'Choose the markdown mirror folder',
    });
    return result.canceled || result.filePaths.length === 0 ? null : result.filePaths[0];
  });

  ipcMain.handle('hermes:sync', () => hermes.sync());
  ipcMain.handle('hermes:status', () => hermes.status());
  ipcMain.handle('hermes:routeToWiki', (_e, noteId: string) => hermes.routeToWiki(noteId));
  ipcMain.handle('hermes:pushTelegram', (_e, text: string, replyTo?: string) =>
    hermes.pushToTelegram(text, replyTo)
  );

  ipcMain.handle('ai:available', () => intelligence.available());
  ipcMain.handle('ai:summarize', (_e, text: string) => intelligence.summarize(text));
  ipcMain.handle('ai:tags', (_e, text: string, existing: string[]) =>
    intelligence.suggestTags(text, existing)
  );
  ipcMain.handle('ai:extractTasks', (_e, text: string) => intelligence.extractTasks(text));
  ipcMain.handle('ai:classify', (_e, text: string) => intelligence.classify(text));
  ipcMain.handle('ai:dayStart', (_e, digest: DayStartDigest) =>
    intelligence.dayStartBriefing(digest)
  );

  ipcMain.handle('calendar:events', (_e, dayISO: string) => icsEvents(dayISO));
}

function createWindow(): void {
  win = new BrowserWindow({
    width: 1200,
    height: 800,
    minWidth: 800,
    minHeight: 560,
    title: 'Hermes Notes',
    backgroundColor: '#f4f4f1',
    webPreferences: {
      preload: path.join(__dirname, '../preload/index.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  win.loadFile(path.join(__dirname, '../renderer/index.html'));
  win.on('closed', () => {
    win = null;
  });

  // Opportunistic Hermes sync when the window regains focus.
  win.on('focus', () => {
    void hermes.sync();
  });
}

app.whenReady().then(() => {
  registerIpc();
  createWindow();

  // Global quick capture: works from anywhere on the desktop.
  globalShortcut.register('CommandOrControl+Shift+Space', () => {
    if (!win) createWindow();
    win?.show();
    win?.focus();
    win?.webContents.send('quick-capture');
  });

  void hermes.sync();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

// Referenced so the userData path stays available for future storage needs.
void userData;
