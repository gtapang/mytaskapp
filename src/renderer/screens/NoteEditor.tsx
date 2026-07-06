import { useEffect, useRef, useState } from 'react';
import type { Note } from '../../core/types';
import type { ExtractedTaskSuggestion } from '../../shared/api';
import { MarkdownPreview } from '../components/Markdown';
import { TaskRow } from '../components/TaskRow';
import { api, newTask, nowISO, useApp } from '../state';

/**
 * Markdown editing with a readable preview one tap away. AI assists and
 * Hermes actions live behind single toolbar buttons — present when wanted,
 * invisible otherwise. Saves are debounced and mirrored to the markdown
 * folder automatically.
 */
export function NoteEditor({ note }: { note: Note }) {
  const { data, refresh, openNote } = useApp();
  const [draft, setDraft] = useState<Note>({ ...note });
  const [mode, setMode] = useState<'edit' | 'read'>('edit');
  const [organizerOpen, setOrganizerOpen] = useState(false);
  const [summary, setSummary] = useState<string | null>(null);
  const [suggestedTags, setSuggestedTags] = useState<string[]>([]);
  const [extracted, setExtracted] = useState<ExtractedTaskSuggestion[] | null>(null);
  const [working, setWorking] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [aiAvailable, setAiAvailable] = useState(false);
  const [hermesConfigured, setHermesConfigured] = useState(false);

  const saveTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const linkedTasks = data.tasks.filter((t) => t.noteId === draft.id);

  useEffect(() => {
    void api.aiAvailable().then(setAiAvailable);
    void api.hermesStatus().then((s) => setHermesConfigured(s.configured));
  }, []);

  const scheduleSave = (updated: Note) => {
    setDraft(updated);
    if (saveTimer.current) clearTimeout(saveTimer.current);
    saveTimer.current = setTimeout(() => {
      void api.saveNote(updated).then(refresh);
    }, 500);
  };

  const set = <K extends keyof Note>(key: K, value: Note[K]) =>
    scheduleSave({ ...draft, [key]: value, updatedAt: nowISO() });

  // Flush pending save on unmount; delete accidental empties.
  useEffect(() => {
    return () => {
      if (saveTimer.current) clearTimeout(saveTimer.current);
    };
  }, []);

  const back = async () => {
    if (saveTimer.current) clearTimeout(saveTimer.current);
    if (draft.title.trim() === '' && draft.markdown.trim() === '' && linkedTasks.length === 0) {
      await api.deleteNote(draft.id); // never keep accidental empties
    } else {
      await api.saveNote(draft);
    }
    await refresh();
    openNote(null);
  };

  const flash = (message: string) => {
    setToast(message);
    setTimeout(() => setToast(null), 2500);
  };

  const run = async (work: () => Promise<void>) => {
    setWorking(true);
    try {
      await work();
    } finally {
      setWorking(false);
    }
  };

  const summarize = () =>
    run(async () => setSummary(await api.aiSummarize(draft.markdown)));

  const suggestTags = () =>
    run(async () => {
      const existing = [...new Set(data.notes.flatMap((n) => n.tags))];
      const tags = await api.aiSuggestTags(draft.markdown, existing);
      setSuggestedTags(tags.filter((t) => !draft.tags.includes(t)));
    });

  const extractTasks = () =>
    run(async () => {
      const suggestions = await api.aiExtractTasks(draft.markdown);
      setExtracted(suggestions.length > 0 ? suggestions : null);
      if (suggestions.length === 0) flash('No actionable tasks found.');
    });

  const acceptExtracted = async (accepted: ExtractedTaskSuggestion[]) => {
    for (const suggestion of accepted) {
      await api.saveTask(newTask(suggestion.title, { priority: suggestion.priority, noteId: draft.id }));
    }
    setExtracted(null);
    await refresh();
  };

  return (
    <div className="screen">
      <div className="toolbar">
        <button className="quiet" onClick={back}>
          ← Back
        </button>
        <div className="grow" />
        <button className="quiet" onClick={() => setMode(mode === 'edit' ? 'read' : 'edit')}>
          {mode === 'edit' ? 'Read' : 'Edit'}
        </button>
        <button
          className="quiet"
          disabled={working || draft.markdown.trim().length === 0}
          title={aiAvailable ? 'AI assists (local model)' : 'AI assists (rule-based; configure a local model in Settings)'}
          onClick={() => {
            /* menu below */
          }}
          style={{ display: 'none' }}
        />
        <button className="quiet" disabled={working || !draft.markdown.trim()} onClick={summarize}>
          {working ? '…' : '✦ Summarize'}
        </button>
        <button className="quiet" disabled={working || !draft.markdown.trim()} onClick={suggestTags}>
          ✦ Tags
        </button>
        <button className="quiet" disabled={working || !draft.markdown.trim()} onClick={extractTasks}>
          ✦ Extract tasks
        </button>
        <button
          className="quiet"
          disabled={!hermesConfigured}
          title={hermesConfigured ? 'Route into the Hermes wiki workflow' : 'Configure Hermes in Settings'}
          onClick={async () => {
            await api.saveNote(draft);
            await api.routeToWiki(draft.id);
            flash('Queued for the wiki workflow.');
          }}
        >
          ↗ Wiki
        </button>
        <button
          className="quiet"
          disabled={!hermesConfigured}
          onClick={async () => {
            await api.pushTelegram(`${draft.title || 'Untitled'}\n\n${draft.markdown}`);
            flash('Queued for Telegram.');
          }}
        >
          ↗ Telegram
        </button>
        <button className="quiet" onClick={() => set('pinned', !draft.pinned)}>
          {draft.pinned ? 'Unpin' : 'Pin'}
        </button>
        <button className="quiet" onClick={() => setOrganizerOpen(true)}>
          Organize
        </button>
      </div>

      {toast && <div className="banner">{toast}</div>}

      {summary && (
        <div className="banner">
          <span>✦</span>
          <span className="grow">{summary}</span>
          <button className="quiet" onClick={() => setSummary(null)}>
            ×
          </button>
        </div>
      )}

      {suggestedTags.length > 0 && (
        <div className="banner">
          <span>Tags:</span>
          {suggestedTags.map((tag) => (
            <button
              key={tag}
              className="chip"
              onClick={() => {
                set('tags', [...draft.tags, tag]);
                setSuggestedTags((s) => s.filter((t) => t !== tag));
              }}
            >
              + {tag}
            </button>
          ))}
          <button className="quiet" onClick={() => setSuggestedTags([])}>
            ×
          </button>
        </div>
      )}

      <input
        type="text"
        placeholder="Title"
        value={draft.title}
        onChange={(e) => set('title', e.target.value)}
        style={{ width: '100%', fontSize: 19, fontWeight: 650, border: 'none', background: 'transparent', padding: '4px 0' }}
      />

      {draft.tags.length > 0 && (
        <div style={{ margin: '6px 0' }}>
          {draft.tags.map((tag) => (
            <span className="tag" key={tag}>
              #{tag}
            </span>
          ))}
        </div>
      )}

      {mode === 'edit' ? (
        <textarea
          className="editor"
          placeholder="Write in markdown…"
          value={draft.markdown}
          onChange={(e) => set('markdown', e.target.value)}
        />
      ) : (
        <MarkdownPreview markdown={draft.markdown} />
      )}

      {linkedTasks.length > 0 && (
        <>
          <div className="section-label">Linked tasks</div>
          {linkedTasks.map((t) => (
            <TaskRow key={t.id} task={t} />
          ))}
        </>
      )}

      {organizerOpen && (
        <NoteOrganizer note={draft} onChange={scheduleSave} onClose={() => setOrganizerOpen(false)} />
      )}

      {extracted && (
        <ExtractedTasksReview
          suggestions={extracted}
          onCancel={() => setExtracted(null)}
          onAccept={acceptExtracted}
        />
      )}
    </div>
  );
}

/** Progressive disclosure home for tags, folder, notebook, project, reminder, archive. */
function NoteOrganizer({
  note,
  onChange,
  onClose,
}: {
  note: Note;
  onChange: (note: Note) => void;
  onClose: () => void;
}) {
  const { data } = useApp();
  const [newTag, setNewTag] = useState('');

  const set = <K extends keyof Note>(key: K, value: Note[K]) =>
    onChange({ ...note, [key]: value, updatedAt: nowISO() });

  const addTag = () => {
    const tag = newTag.trim().toLowerCase();
    if (tag && !note.tags.includes(tag)) set('tags', [...note.tags, tag]);
    setNewTag('');
  };

  const datalist = (values: Array<string | undefined>) =>
    [...new Set(values.filter((v): v is string => !!v))].sort();

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>Organize</h2>

        <div className="form-row">
          <label>Tags</label>
          <div className="grow">
            {note.tags.map((tag) => (
              <button className="chip" key={tag} onClick={() => set('tags', note.tags.filter((t) => t !== tag))}>
                #{tag} ×
              </button>
            ))}
            <input
              type="text"
              placeholder="Add tag"
              value={newTag}
              onChange={(e) => setNewTag(e.target.value)}
              onKeyDown={(e) => e.key === 'Enter' && addTag()}
              style={{ marginTop: 6, width: '100%' }}
            />
          </div>
        </div>

        {(
          [
            ['Folder', 'folder', datalist(data.notes.map((n) => n.folder))],
            ['Notebook', 'notebook', datalist(data.notes.map((n) => n.notebook))],
            ['Project', 'project', datalist([...data.notes.map((n) => n.project), ...data.projects.map((p) => p.name)])],
          ] as Array<[string, 'folder' | 'notebook' | 'project', string[]]>
        ).map(([label, key, options]) => (
          <div className="form-row" key={key}>
            <label>{label}</label>
            <input
              type="text"
              list={`options-${key}`}
              value={note[key] ?? ''}
              onChange={(e) => set(key, e.target.value ? e.target.value : undefined)}
            />
            <datalist id={`options-${key}`}>
              {options.map((o) => (
                <option key={o} value={o} />
              ))}
            </datalist>
          </div>
        ))}

        <div className="form-row">
          <label>Reminder</label>
          <input
            type="datetime-local"
            value={note.reminderAt?.slice(0, 16) ?? ''}
            onChange={(e) => set('reminderAt', e.target.value ? e.target.value : undefined)}
          />
        </div>

        <div className="form-row">
          <label>Archived</label>
          <input
            type="checkbox"
            checked={note.archived}
            onChange={(e) => set('archived', e.target.checked)}
            style={{ width: 'auto' }}
          />
        </div>

        <div className="row" style={{ marginTop: 14 }}>
          <div className="grow" />
          <button className="primary" onClick={onClose}>
            Done
          </button>
        </div>
      </div>
    </div>
  );
}

/** Review sheet for extracted tasks: nothing becomes a task until confirmed. */
function ExtractedTasksReview({
  suggestions,
  onAccept,
  onCancel,
}: {
  suggestions: ExtractedTaskSuggestion[];
  onAccept: (accepted: ExtractedTaskSuggestion[]) => void;
  onCancel: () => void;
}) {
  const [selected, setSelected] = useState<Set<number>>(new Set(suggestions.map((_, i) => i)));

  const toggle = (i: number) =>
    setSelected((s) => {
      const next = new Set(s);
      if (next.has(i)) next.delete(i);
      else next.add(i);
      return next;
    });

  return (
    <div className="modal-backdrop" onClick={onCancel}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>Extracted tasks</h2>
        {suggestions.map((suggestion, i) => (
          <div className="card clickable row" key={i} onClick={() => toggle(i)}>
            <span style={{ color: selected.has(i) ? 'var(--accent)' : 'var(--text-3)' }}>
              {selected.has(i) ? '●' : '○'}
            </span>
            <div className="grow">
              <div>{suggestion.title}</div>
              {suggestion.dueHint && <div className="faint">{suggestion.dueHint}</div>}
            </div>
          </div>
        ))}
        <div className="row" style={{ marginTop: 12 }}>
          <div className="grow" />
          <button className="quiet" onClick={onCancel}>
            Cancel
          </button>
          <button
            className="primary"
            disabled={selected.size === 0}
            onClick={() => onAccept(suggestions.filter((_, i) => selected.has(i)))}
          >
            Add {selected.size}
          </button>
        </div>
      </div>
    </div>
  );
}
