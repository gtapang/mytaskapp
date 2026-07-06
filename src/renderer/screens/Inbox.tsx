import { useEffect, useState } from 'react';
import type { InboxItem } from '../../core/types';
import { api, newNote, newTask, relativeTime, useApp } from '../state';

const SUGGESTION_LABEL: Record<string, string> = {
  note: 'Looks like a note',
  task: 'Looks like a task',
  note_and_task: 'Note + task',
  reference: 'Reference',
};

/**
 * Processing surface for captured thoughts — local quick captures and
 * Telegram captures arriving through Hermes. Each item becomes a note, a
 * task, or both; the local classifier suggests which, never decides.
 */
export function Inbox() {
  const { data, refresh, setCaptureOpen } = useApp();
  const [showProcessed, setShowProcessed] = useState(false);
  const [aiAvailable, setAiAvailable] = useState(false);

  useEffect(() => {
    void api.aiAvailable().then(setAiAvailable);
  }, []);

  const visible = data.inbox
    .filter((i) => i.processed === showProcessed)
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));

  // Classify unprocessed unknowns once, on demand, only when a model exists.
  useEffect(() => {
    if (!aiAvailable) return;
    let cancelled = false;
    (async () => {
      for (const item of data.inbox.filter((i) => !i.processed && i.suggestedKind === 'unknown')) {
        const kind = await api.aiClassify(item.rawContent);
        if (cancelled) return;
        if (kind !== 'unknown') {
          await api.updateInbox({ ...item, suggestedKind: kind });
        }
      }
      if (!cancelled) await refresh();
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aiAvailable, data.inbox.length]);

  const convert = async (item: InboxItem, toNote: boolean, toTask: boolean) => {
    const lines = item.rawContent.split('\n').filter((l) => l.trim().length > 0);
    const title = (lines[0] ?? 'Captured item').slice(0, 80);
    const body = lines.slice(1).join('\n');

    const updated: InboxItem = { ...item, processed: true };
    if (toNote) {
      const note = newNote({ title, markdown: body });
      await api.saveNote(note);
      updated.resultingNoteId = note.id;
    }
    if (toTask) {
      const task = newTask(title, { noteId: updated.resultingNoteId });
      await api.saveTask(task);
      updated.resultingTaskId = task.id;
    }
    await api.updateInbox(updated);

    // Close the loop for Telegram captures: confirm back through Hermes.
    if (item.source === 'telegram' && item.sourceId) {
      const made = [toNote ? 'note' : null, toTask ? 'task' : null].filter(Boolean).join(' + ');
      await api.pushTelegram(`Filed as ${made}: ${title}`, item.sourceId);
    }
    await refresh();
  };

  return (
    <div className="screen">
      <div className="row" style={{ alignItems: 'center' }}>
        <h1 style={{ marginBottom: 0 }}>Inbox</h1>
        <div className="grow" />
        <button className="quiet" onClick={() => setShowProcessed((v) => !v)}>
          {showProcessed ? 'Show unprocessed' : 'Show processed'}
        </button>
        <button className="primary" onClick={() => setCaptureOpen(true)}>
          + Capture
        </button>
      </div>

      <div style={{ marginTop: 16 }}>
        {visible.map((item) => (
          <div className="card" key={item.id}>
            <div className="row">
              <span className="faint">
                {item.source === 'telegram' ? '✈ Telegram' : '⌨ Capture'} · {relativeTime(item.createdAt)}
              </span>
              <div className="grow" />
              {item.suggestedKind !== 'unknown' && (
                <span className="tag">{SUGGESTION_LABEL[item.suggestedKind]}</span>
              )}
            </div>
            <div style={{ margin: '7px 0', whiteSpace: 'pre-wrap' }}>{item.rawContent}</div>
            {!item.processed && (
              <div className="row">
                <button className="chip" onClick={() => convert(item, true, false)}>
                  Note
                </button>
                <button className="chip" onClick={() => convert(item, false, true)}>
                  Task
                </button>
                <button className="chip" onClick={() => convert(item, true, true)}>
                  Both
                </button>
                <div className="grow" />
                <button
                  className="quiet"
                  title="Mark processed"
                  onClick={async () => {
                    await api.updateInbox({ ...item, processed: true });
                    await refresh();
                  }}
                >
                  ✓
                </button>
                <button
                  className="quiet"
                  style={{ color: 'var(--danger)' }}
                  title="Delete"
                  onClick={async () => {
                    await api.deleteInbox(item.id);
                    await refresh();
                  }}
                >
                  ×
                </button>
              </div>
            )}
          </div>
        ))}

        {visible.length === 0 && (
          <div className="empty">
            {showProcessed ? 'Nothing processed yet.' : 'Inbox zero. Captures from here and Telegram land in this list.'}
          </div>
        )}
      </div>
    </div>
  );
}
