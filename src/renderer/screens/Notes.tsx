import { useState } from 'react';
import { plainTextPreview } from '../../core/markdown';
import type { Note } from '../../core/types';
import { api, displayTitle, newNote, relativeTime, useApp } from '../state';

/**
 * The notes home: search, pinned, then everything recent. Organization
 * (tags, folders, notebooks, projects) lives inside each note's organizer —
 * the list itself stays quiet.
 */
export function Notes() {
  const { data, refresh, openNote } = useApp();
  const [search, setSearch] = useState('');
  const [showArchived, setShowArchived] = useState(false);

  const query = search.trim().toLowerCase();
  const visible = data.notes
    .filter((n) => n.archived === showArchived)
    .filter(
      (n) =>
        query.length === 0 ||
        n.title.toLowerCase().includes(query) ||
        n.markdown.toLowerCase().includes(query) ||
        n.tags.some((t) => t.toLowerCase().includes(query))
    )
    .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));

  const pinned = visible.filter((n) => n.pinned);
  const rest = visible.filter((n) => !n.pinned);

  const create = async () => {
    const note = newNote();
    await api.saveNote(note);
    await refresh();
    openNote(note.id);
  };

  const row = (note: Note) => {
    const preview = plainTextPreview(note.markdown);
    const taskCount = data.tasks.filter((t) => t.noteId === note.id).length;
    return (
      <div className="card clickable" key={note.id} onClick={() => openNote(note.id)}>
        <div className="row">
          <span style={{ fontWeight: 550 }}>
            {note.pinned && '📌 '}
            {displayTitle(note)}
          </span>
          <div className="grow" />
          {note.reminderAt && <span className="faint">🔔</span>}
        </div>
        {preview && <div className="muted" style={{ fontSize: 13 }}>{preview}</div>}
        <div className="faint">
          {relativeTime(note.updatedAt)}
          {taskCount > 0 && ` · ${taskCount} task${taskCount === 1 ? '' : 's'}`}
          {note.notebook && ` · ${note.notebook}`}
          {note.tags.length > 0 && ` · ${note.tags.map((t) => `#${t}`).join(' ')}`}
        </div>
      </div>
    );
  };

  return (
    <div className="screen">
      <div className="row" style={{ alignItems: 'center' }}>
        <h1 style={{ marginBottom: 0 }}>{showArchived ? 'Archive' : 'Notes'}</h1>
        <div className="grow" />
        <button className="quiet" onClick={() => setShowArchived((v) => !v)}>
          {showArchived ? 'Back to notes' : 'Archive'}
        </button>
        <button className="primary" onClick={create}>
          + New note
        </button>
      </div>

      <div style={{ margin: '14px 0' }}>
        <input
          type="text"
          placeholder="Search notes"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          style={{ width: '100%' }}
        />
      </div>

      {pinned.length > 0 && (
        <>
          <div className="section-label">Pinned</div>
          {pinned.map(row)}
        </>
      )}
      {pinned.length > 0 && rest.length > 0 && <div className="section-label">Notes</div>}
      {rest.map(row)}

      {visible.length === 0 && (
        <div className="empty">
          {showArchived ? 'No archived notes.' : 'No notes yet — capture something.'}
        </div>
      )}
    </div>
  );
}
