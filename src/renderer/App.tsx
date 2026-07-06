import { useCallback, useEffect, useMemo, useState } from 'react';
import type { AppData } from '../core/types';
import { AppContext, api, uuid, type Screen } from './state';
import { Calendar } from './screens/Calendar';
import { Eisenhower } from './screens/Eisenhower';
import { Inbox } from './screens/Inbox';
import { NoteEditor } from './screens/NoteEditor';
import { Notes } from './screens/Notes';
import { SettingsModal } from './screens/Settings';
import { Tasks } from './screens/Tasks';
import { Today } from './screens/Today';

const NAV: Array<{ screen: Screen; label: string; icon: string }> = [
  { screen: 'today', label: 'Today', icon: '☀' },
  { screen: 'notes', label: 'Notes', icon: '📝' },
  { screen: 'calendar', label: 'Calendar', icon: '📅' },
  { screen: 'tasks', label: 'Tasks', icon: '✓' },
  { screen: 'eisenhower', label: 'Eisenhower', icon: '⊞' },
  { screen: 'inbox', label: 'Inbox', icon: '📥' },
];

export function App() {
  const [data, setData] = useState<AppData | null>(null);
  const [screen, setScreen] = useState<Screen>('today');
  const [openNoteId, setOpenNoteId] = useState<string | null>(null);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [captureOpen, setCaptureOpen] = useState(false);

  const refresh = useCallback(async () => {
    setData(await api.getData());
  }, []);

  useEffect(() => {
    void refresh();
    api.onQuickCapture(() => setCaptureOpen(true));
  }, [refresh]);

  const openNote = useCallback((id: string | null) => {
    setOpenNoteId(id);
    if (id) setScreen('notes');
  }, []);

  const state = useMemo(
    () =>
      data && {
        data,
        refresh,
        screen,
        setScreen: (s: Screen) => {
          setOpenNoteId(null);
          setScreen(s);
        },
        openNote,
        openNoteId,
        setSettingsOpen,
        setCaptureOpen,
      },
    [data, refresh, screen, openNote, openNoteId]
  );

  if (!state || !data) return null;

  const inboxCount = data.inbox.filter((i) => !i.processed).length;
  const openedNote = openNoteId ? data.notes.find((n) => n.id === openNoteId) : undefined;

  return (
    <AppContext.Provider value={state}>
      <div className="app">
        <nav className="nav">
          {NAV.map(({ screen: s, label, icon }) => (
            <button
              key={s}
              className={screen === s && !settingsOpen ? 'active' : ''}
              onClick={() => state.setScreen(s)}
            >
              <span>{icon}</span>
              <span>{label}</span>
              {s === 'inbox' && inboxCount > 0 && <span className="badge">{inboxCount}</span>}
            </button>
          ))}
          <div className="spacer" />
          <button onClick={() => setSettingsOpen(true)}>
            <span>⚙</span>
            <span>Settings</span>
          </button>
        </nav>

        {openedNote ? (
          <NoteEditor key={openedNote.id} note={openedNote} />
        ) : (
          <ScreenBody screen={screen} />
        )}

        {settingsOpen && <SettingsModal onClose={() => setSettingsOpen(false)} />}
        {captureOpen && <QuickCapture onClose={() => setCaptureOpen(false)} refresh={refresh} />}
      </div>
    </AppContext.Provider>
  );
}

function ScreenBody({ screen }: { screen: Screen }) {
  switch (screen) {
    case 'today':
      return <Today />;
    case 'notes':
      return <Notes />;
    case 'calendar':
      return <Calendar />;
    case 'tasks':
      return <Tasks />;
    case 'eisenhower':
      return <Eisenhower />;
    case 'inbox':
      return <Inbox />;
  }
}

/** The fastest path into the system: text in, inbox item out, done. */
function QuickCapture({
  onClose,
  refresh,
}: {
  onClose: () => void;
  refresh: () => Promise<void>;
}) {
  const [text, setText] = useState('');

  const save = async () => {
    const content = text.trim();
    if (!content) return;
    await api.addInbox({
      id: uuid(),
      source: 'local_capture',
      rawContent: content,
      createdAt: new Date().toISOString(),
      processed: false,
      suggestedKind: 'unknown',
    });
    await refresh();
    onClose();
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()} style={{ width: 'min(480px, 92vw)' }}>
        <h2>Capture</h2>
        <textarea
          autoFocus
          placeholder="What's on your mind?"
          value={text}
          onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) void save();
            if (e.key === 'Escape') onClose();
          }}
          style={{ width: '100%', minHeight: 90, resize: 'vertical' }}
        />
        <div className="row" style={{ marginTop: 12 }}>
          <span className="faint">⌘/Ctrl+Enter to save</span>
          <div className="grow" />
          <button className="quiet" onClick={onClose}>
            Cancel
          </button>
          <button className="primary" disabled={text.trim().length === 0} onClick={() => void save()}>
            Save to Inbox
          </button>
        </div>
      </div>
    </div>
  );
}
