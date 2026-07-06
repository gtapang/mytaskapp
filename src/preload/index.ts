import { contextBridge, ipcRenderer } from 'electron';
import type { DayStartDigest } from '../core/dayStart';
import type { InboxItem, Note, Project, Settings, TaskItem } from '../core/types';
import type { HermesNotesApi } from '../shared/api';

/** The typed bridge the renderer sees as `window.hermes`. */
const api: HermesNotesApi = {
  getData: () => ipcRenderer.invoke('data:get'),

  saveNote: (note: Note) => ipcRenderer.invoke('note:save', note),
  deleteNote: (id: string) => ipcRenderer.invoke('note:delete', id),
  saveTask: (task: TaskItem) => ipcRenderer.invoke('task:save', task),
  deleteTask: (id: string) => ipcRenderer.invoke('task:delete', id),
  saveProject: (project: Project) => ipcRenderer.invoke('project:save', project),
  addInbox: (item: InboxItem) => ipcRenderer.invoke('inbox:add', item),
  updateInbox: (item: InboxItem) => ipcRenderer.invoke('inbox:update', item),
  deleteInbox: (id: string) => ipcRenderer.invoke('inbox:delete', id),
  saveSettings: (settings: Settings) => ipcRenderer.invoke('settings:save', settings),
  pickMirrorDir: () => ipcRenderer.invoke('settings:pickMirrorDir'),

  hermesSync: () => ipcRenderer.invoke('hermes:sync'),
  hermesStatus: () => ipcRenderer.invoke('hermes:status'),
  routeToWiki: (noteId: string) => ipcRenderer.invoke('hermes:routeToWiki', noteId),
  pushTelegram: (text: string, replyToCaptureID?: string) =>
    ipcRenderer.invoke('hermes:pushTelegram', text, replyToCaptureID),
  dismissContext: (sourceId: string) => ipcRenderer.invoke('hermes:dismissContext', sourceId),

  aiAvailable: () => ipcRenderer.invoke('ai:available'),
  aiSummarize: (text: string) => ipcRenderer.invoke('ai:summarize', text),
  aiSuggestTags: (text: string, existing: string[]) => ipcRenderer.invoke('ai:tags', text, existing),
  aiExtractTasks: (text: string) => ipcRenderer.invoke('ai:extractTasks', text),
  aiClassify: (text: string) => ipcRenderer.invoke('ai:classify', text),
  aiDayStart: (digest: DayStartDigest) => ipcRenderer.invoke('ai:dayStart', digest),

  calendarEvents: (dayISO: string) => ipcRenderer.invoke('calendar:events', dayISO),

  onQuickCapture: (callback: () => void) => {
    ipcRenderer.on('quick-capture', callback);
  },
};

contextBridge.exposeInMainWorld('hermes', api);
