import { useState } from 'react';
import {
  isTerminal,
  priorityRank,
  QUADRANT_MATRIX,
  quadrantShortName,
  type EisenhowerQuadrant,
  type TaskItem,
} from '../../core/types';
import { api, nowISO, PRIORITY_COLOR, useApp } from '../state';

const QUADRANT_TINT: Record<string, string> = {
  urgent_important: 'var(--danger)',
  important_not_urgent: 'var(--accent)',
  urgent_not_important: 'var(--warn)',
  not_urgent_not_important: 'var(--text-3)',
};

/**
 * Dedicated planning screen: a real four-quadrant matrix, not a filtered
 * list. Drag tasks between quadrants; a quiet tray below holds unassigned
 * open tasks.
 */
export function Eisenhower() {
  const { data, refresh } = useApp();
  const [targeted, setTargeted] = useState<EisenhowerQuadrant | 'unassigned' | null>(null);

  const open = data.tasks.filter((t) => !isTerminal(t.status));
  const inQuadrant = (q: EisenhowerQuadrant) =>
    open.filter((t) => t.quadrant === q).sort((a, b) => priorityRank(b.priority) - priorityRank(a.priority));

  const moveTo = async (taskId: string, quadrant: EisenhowerQuadrant) => {
    const task = data.tasks.find((t) => t.id === taskId);
    if (!task) return;
    await api.saveTask({ ...task, quadrant, updatedAt: nowISO() });
    await refresh();
  };

  const dropProps = (quadrant: EisenhowerQuadrant) => ({
    onDragOver: (e: React.DragEvent) => {
      e.preventDefault();
      setTargeted(quadrant);
    },
    onDragLeave: () => setTargeted(null),
    onDrop: (e: React.DragEvent) => {
      e.preventDefault();
      setTargeted(null);
      const id = e.dataTransfer.getData('text/task-id');
      if (id) void moveTo(id, quadrant);
    },
  });

  const chip = (task: TaskItem) => (
    <div
      className="chip-task"
      key={task.id}
      draggable
      onDragStart={(e) => e.dataTransfer.setData('text/task-id', task.id)}
    >
      {task.priority !== 'none' && (
        <span className="dot" style={{ background: PRIORITY_COLOR[task.priority] }} />
      )}
      <span>{task.title}</span>
    </div>
  );

  const unassigned = inQuadrant('unassigned');

  return (
    <div className="screen">
      <h1>Eisenhower</h1>
      <div className="faint" style={{ marginBottom: 12 }}>
        Urgent ↔ not urgent across · important ↕ not important down. Drag tasks to plan.
      </div>

      <div className="matrix">
        {QUADRANT_MATRIX.map((quadrant) => {
          const tasks = inQuadrant(quadrant);
          return (
            <div
              key={quadrant}
              className={`quadrant${targeted === quadrant ? ' targeted' : ''}`}
              {...dropProps(quadrant)}
            >
              <div className="row">
                <span style={{ fontWeight: 600, color: QUADRANT_TINT[quadrant] }}>
                  {quadrantShortName(quadrant)}
                </span>
                <div className="grow" />
                <span className="faint">{tasks.length}</span>
              </div>
              {tasks.length === 0 ? (
                <div className="faint" style={{ marginTop: 18, textAlign: 'center' }}>
                  Drop tasks here
                </div>
              ) : (
                tasks.map(chip)
              )}
            </div>
          );
        })}
      </div>

      <div className="section-label">Unassigned</div>
      <div
        className={`quadrant${targeted === 'unassigned' ? ' targeted' : ''}`}
        style={{ minHeight: 60 }}
        onDragOver={(e) => {
          e.preventDefault();
          setTargeted('unassigned');
        }}
        onDragLeave={() => setTargeted(null)}
        onDrop={(e) => {
          e.preventDefault();
          setTargeted(null);
          const id = e.dataTransfer.getData('text/task-id');
          if (id) void moveTo(id, 'unassigned');
        }}
      >
        {unassigned.length === 0 ? (
          <div className="faint" style={{ textAlign: 'center', paddingTop: 8 }}>
            Everything is placed. Drag tasks here to unplan them.
          </div>
        ) : (
          unassigned.map(chip)
        )}
      </div>
    </div>
  );
}
