import { isOverdue, type TaskItem } from '../../core/types';
import { api, displayTitle, nowISO, PRIORITY_COLOR, useApp } from '../state';

/**
 * The one task row used everywhere: check toggle, quiet metadata, optional
 * edit affordance. Reminders render as a single quiet glyph, never a banner.
 */
export function TaskRow({ task, onEdit }: { task: TaskItem; onEdit?: (task: TaskItem) => void }) {
  const { data, refresh } = useApp();
  const done = task.status === 'done';
  const note = task.noteId ? data.notes.find((n) => n.id === task.noteId) : undefined;
  const overdue = isOverdue(task, nowISO());

  const toggle = async () => {
    await api.saveTask({ ...task, status: done ? 'open' : 'done', updatedAt: nowISO() });
    await refresh();
  };

  return (
    <div className="card row" style={{ alignItems: 'center' }}>
      <button
        className="quiet"
        style={{ padding: '2px 6px', fontSize: 16, color: done ? 'var(--accent)' : 'var(--text-3)' }}
        onClick={toggle}
        aria-label={done ? 'Mark open' : 'Mark done'}
      >
        {done ? '●' : '○'}
      </button>
      <div className="grow" style={{ cursor: onEdit ? 'pointer' : 'default' }} onClick={() => onEdit?.(task)}>
        <span style={done ? { textDecoration: 'line-through', color: 'var(--text-2)' } : undefined}>
          {task.title}
        </span>
        <div className="faint">
          {overdue && <span style={{ color: 'var(--danger)' }}>Overdue · </span>}
          {task.dueDate && <span>{task.dueDate.slice(0, 10)} · </span>}
          {note && <span>📝 {displayTitle(note)} · </span>}
          {task.project && <span>{task.project}</span>}
        </div>
      </div>
      {task.reminderAt && <span title="Has reminder" className="faint">🔔</span>}
      {task.priority !== 'none' && (
        <span className="dot" style={{ background: PRIORITY_COLOR[task.priority] }} />
      )}
    </div>
  );
}
