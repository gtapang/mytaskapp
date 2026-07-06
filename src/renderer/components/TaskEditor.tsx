import { useState } from 'react';
import {
  QUADRANT_MATRIX,
  quadrantShortName,
  type EisenhowerQuadrant,
  type TaskItem,
  type TaskPriority,
  type TaskStatus,
} from '../../core/types';
import { api, displayTitle, nowISO, useApp } from '../state';

/** Small focused editor for one task, shown as a modal. */
export function TaskEditor({ task, onClose }: { task: TaskItem; onClose: () => void }) {
  const { data, refresh } = useApp();
  const [draft, setDraft] = useState<TaskItem>({ ...task });

  const set = <K extends keyof TaskItem>(key: K, value: TaskItem[K]) =>
    setDraft((d) => ({ ...d, [key]: value }));

  const save = async () => {
    await api.saveTask({ ...draft, updatedAt: nowISO() });
    await refresh();
    onClose();
  };

  const remove = async () => {
    await api.deleteTask(draft.id);
    await refresh();
    onClose();
  };

  return (
    <div className="modal-backdrop" onClick={onClose}>
      <div className="modal" onClick={(e) => e.stopPropagation()}>
        <h2>Task</h2>

        <div className="form-row">
          <label>Title</label>
          <input type="text" value={draft.title} onChange={(e) => set('title', e.target.value)} />
        </div>

        <div className="form-row">
          <label>Status</label>
          <select value={draft.status} onChange={(e) => set('status', e.target.value as TaskStatus)}>
            <option value="open">Open</option>
            <option value="in_progress">In progress</option>
            <option value="done">Done</option>
            <option value="dropped">Dropped</option>
          </select>
        </div>

        <div className="form-row">
          <label>Due date</label>
          <input
            type="date"
            value={draft.dueDate?.slice(0, 10) ?? ''}
            onChange={(e) => set('dueDate', e.target.value ? e.target.value : undefined)}
          />
        </div>

        <div className="form-row">
          <label>Reminder</label>
          <input
            type="datetime-local"
            value={draft.reminderAt?.slice(0, 16) ?? ''}
            onChange={(e) => set('reminderAt', e.target.value ? e.target.value : undefined)}
          />
        </div>

        <div className="form-row">
          <label>Priority</label>
          <select
            value={draft.priority}
            onChange={(e) => set('priority', e.target.value as TaskPriority)}
          >
            <option value="none">None</option>
            <option value="low">Low</option>
            <option value="medium">Medium</option>
            <option value="high">High</option>
          </select>
        </div>

        <div className="form-row">
          <label>Quadrant</label>
          <select
            value={draft.quadrant}
            onChange={(e) => set('quadrant', e.target.value as EisenhowerQuadrant)}
          >
            <option value="unassigned">Unassigned</option>
            {QUADRANT_MATRIX.map((q) => (
              <option key={q} value={q}>
                {quadrantShortName(q)}
              </option>
            ))}
          </select>
        </div>

        <div className="form-row">
          <label>Project</label>
          <select
            value={draft.project ?? ''}
            onChange={(e) => set('project', e.target.value ? e.target.value : undefined)}
          >
            <option value="">None</option>
            {data.projects.map((p) => (
              <option key={p.id} value={p.name}>
                {p.name}
              </option>
            ))}
          </select>
        </div>

        <div className="form-row">
          <label>Linked note</label>
          <select
            value={draft.noteId ?? ''}
            onChange={(e) => set('noteId', e.target.value ? e.target.value : undefined)}
          >
            <option value="">None</option>
            {data.notes
              .filter((n) => !n.archived)
              .slice(0, 50)
              .map((n) => (
                <option key={n.id} value={n.id}>
                  {displayTitle(n)}
                </option>
              ))}
          </select>
        </div>

        <div className="row" style={{ marginTop: 16 }}>
          <button className="quiet" style={{ color: 'var(--danger)' }} onClick={remove}>
            Delete
          </button>
          <div className="grow" />
          <button className="quiet" onClick={onClose}>
            Cancel
          </button>
          <button className="primary" onClick={save} disabled={draft.title.trim().length === 0}>
            Save
          </button>
        </div>
      </div>
    </div>
  );
}
