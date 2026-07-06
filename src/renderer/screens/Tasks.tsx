import { useState } from 'react';
import { isDueOn, isOverdue, isTerminal, type TaskItem } from '../../core/types';
import { TaskEditor } from '../components/TaskEditor';
import { TaskRow } from '../components/TaskRow';
import { api, newTask, nowISO, todayISO, useApp } from '../state';

/** Task home: filter and group without dashboard density. */
export function Tasks() {
  const { data, refresh } = useApp();
  const [grouping, setGrouping] = useState<'date' | 'project'>('date');
  const [showCompleted, setShowCompleted] = useState(false);
  const [editing, setEditing] = useState<TaskItem | null>(null);
  const [newTitle, setNewTitle] = useState('');

  const visible = data.tasks.filter((t) => showCompleted || !isTerminal(t.status));

  const add = async () => {
    const title = newTitle.trim();
    if (!title) return;
    await api.saveTask(newTask(title));
    setNewTitle('');
    await refresh();
  };

  const groups: Array<{ title: string; tasks: TaskItem[] }> = [];
  if (grouping === 'date') {
    const day = todayISO();
    const overdue = visible.filter((t) => isOverdue(t, nowISO()));
    const today = visible.filter((t) => isDueOn(t, day) && !isOverdue(t, nowISO()));
    const upcoming = visible
      .filter((t) => t.dueDate && t.dueDate.slice(0, 10) > day)
      .sort((a, b) => (a.dueDate ?? '').localeCompare(b.dueDate ?? ''));
    const someday = visible.filter((t) => !t.dueDate && !overdue.includes(t));
    for (const [title, tasks] of [
      ['Overdue', overdue],
      ['Today', today],
      ['Upcoming', upcoming],
      ['Someday', someday],
    ] as const) {
      if (tasks.length > 0) groups.push({ title, tasks });
    }
  } else {
    const byProject = new Map<string, TaskItem[]>();
    for (const task of visible) {
      const key = task.project ?? 'No project';
      byProject.set(key, [...(byProject.get(key) ?? []), task]);
    }
    for (const [title, tasks] of [...byProject.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
      groups.push({ title, tasks });
    }
  }

  return (
    <div className="screen">
      <div className="row" style={{ alignItems: 'center' }}>
        <h1 style={{ marginBottom: 0 }}>Tasks</h1>
        <div className="grow" />
        <select value={grouping} onChange={(e) => setGrouping(e.target.value as 'date' | 'project')}>
          <option value="date">By date</option>
          <option value="project">By project</option>
        </select>
        <button className="quiet" onClick={() => setShowCompleted((v) => !v)}>
          {showCompleted ? 'Hide completed' : 'Show completed'}
        </button>
      </div>

      <div className="row" style={{ margin: '14px 0' }}>
        <input
          type="text"
          placeholder="New task"
          value={newTitle}
          onChange={(e) => setNewTitle(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && add()}
          style={{ flex: 1 }}
        />
        <button className="primary" onClick={add} disabled={newTitle.trim().length === 0}>
          Add
        </button>
      </div>

      {groups.map((group) => (
        <div key={group.title}>
          <div className="section-label">{group.title}</div>
          {group.tasks.map((t) => (
            <TaskRow key={t.id} task={t} onEdit={setEditing} />
          ))}
        </div>
      ))}

      {visible.length === 0 && (
        <div className="empty">No open tasks. Tasks you create or extract from notes land here.</div>
      )}

      {editing && <TaskEditor task={editing} onClose={() => setEditing(null)} />}
    </div>
  );
}
