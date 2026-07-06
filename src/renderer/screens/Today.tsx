import { useEffect, useState } from 'react';
import type { DayStartDigest } from '../../core/dayStart';
import { isOverdue, isTerminal, isDueOn } from '../../core/types';
import type { CalendarEvent } from '../../shared/api';
import { TaskRow } from '../components/TaskRow';
import { api, displayTitle, nowISO, relativeTime, todayISO, useApp } from '../state';

/**
 * The default landing screen: a calm day starter. One briefing, today's
 * tasks and events, anything important Hermes surfaced, a few pinned notes,
 * and a quick capture entry point. Nothing else.
 */
export function Today() {
  const { data, refresh, setScreen, openNote, setCaptureOpen, setSettingsOpen } = useApp();
  const [briefing, setBriefing] = useState('');
  const [events, setEvents] = useState<CalendarEvent[]>([]);

  const day = todayISO();
  const openTasks = data.tasks.filter((t) => !isTerminal(t.status));
  const dueTasks = openTasks
    .filter((t) => isDueOn(t, day) || isOverdue(t, nowISO()))
    .sort((a, b) => Number(isOverdue(b, nowISO())) - Number(isOverdue(a, nowISO())));
  const reminders = openTasks
    .filter((t) => t.reminderAt && t.reminderAt >= nowISO())
    .sort((a, b) => (a.reminderAt ?? '').localeCompare(b.reminderAt ?? ''))
    .slice(0, 3);
  const highlights = data.hermesContext
    .filter((c) => !c.dismissed)
    .sort((a, b) => b.importance - a.importance)
    .slice(0, 4);
  const pinned = data.notes.filter((n) => n.pinned && !n.archived).slice(0, 3);
  const inboxCount = data.inbox.filter((i) => !i.processed).length;

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const todaysEvents = await api.calendarEvents(day);
      if (cancelled) return;
      setEvents(todaysEvents);

      const digest: DayStartDigest = {
        dateISO: day,
        dueTasks: dueTasks.map((t) => ({
          title: t.title,
          priority: t.priority,
          quadrant: t.quadrant,
          overdue: isOverdue(t, nowISO()),
        })),
        events: todaysEvents.map((e) => ({ title: e.title, startISO: e.startISO, allDay: e.allDay })),
        hermesHighlights: highlights.map((h) => ({ kind: h.kind, title: h.title })),
        inboxCount,
      };
      const text = await api.aiDayStart(digest);
      if (!cancelled) setBriefing(text);
    })();
    return () => {
      cancelled = true;
    };
    // Re-run when the underlying facts change.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [data]);

  const heading = new Date().toLocaleDateString(undefined, {
    weekday: 'long',
    month: 'long',
    day: 'numeric',
  });

  return (
    <div className="screen">
      <div className="row" style={{ alignItems: 'center' }}>
        <h1 style={{ marginBottom: 0 }}>{heading}</h1>
        <div className="grow" />
        <button className="quiet" onClick={() => setSettingsOpen(true)} aria-label="Settings">
          ⚙
        </button>
        <button className="primary" onClick={() => setCaptureOpen(true)}>
          + Capture
        </button>
      </div>

      <div className="card" style={{ marginTop: 18 }}>
        <div className="section-label" style={{ margin: '0 0 6px' }}>
          Day start
        </div>
        <div>{briefing || 'Gathering your day…'}</div>
        {inboxCount > 0 && (
          <button className="chip" style={{ marginTop: 10 }} onClick={() => setScreen('inbox')}>
            {inboxCount} item{inboxCount === 1 ? '' : 's'} waiting in Inbox
          </button>
        )}
      </div>

      {dueTasks.length > 0 && (
        <>
          <div className="section-label">Due today</div>
          {dueTasks.map((t) => (
            <TaskRow key={t.id} task={t} />
          ))}
        </>
      )}

      {events.length > 0 && (
        <>
          <div className="section-label">Calendar</div>
          {events.map((e) => (
            <div className="card row" key={e.id} style={{ alignItems: 'center' }}>
              <span className="faint" style={{ width: 52 }}>
                {e.allDay ? 'All day' : new Date(e.startISO).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
              </span>
              <span style={{ width: 3, height: 24, background: 'var(--accent)', borderRadius: 2, opacity: 0.6 }} />
              <span>{e.title}</span>
            </div>
          ))}
        </>
      )}

      {highlights.length > 0 && (
        <>
          <div className="section-label">Important, via Hermes</div>
          {highlights.map((h) => (
            <div className="card row" key={h.sourceId}>
              <span>{h.kind === 'email' ? '✉' : h.kind === 'calendar' ? '📅' : '✦'}</span>
              <div className="grow">
                <div style={{ fontWeight: 550 }}>{h.title}</div>
                <div className="faint">{h.summary}</div>
              </div>
              <button
                className="quiet"
                onClick={async () => {
                  await api.dismissContext(h.sourceId);
                  await refresh();
                }}
                aria-label="Dismiss"
              >
                ×
              </button>
            </div>
          ))}
        </>
      )}

      {reminders.length > 0 && (
        <>
          <div className="section-label">Reminders</div>
          {reminders.map((t) => (
            <div className="card row" key={t.id}>
              <span className="faint">🔔</span>
              <span className="grow">{t.title}</span>
              <span className="faint">
                {new Date(t.reminderAt!).toLocaleString([], {
                  month: 'short',
                  day: 'numeric',
                  hour: 'numeric',
                  minute: '2-digit',
                })}
              </span>
            </div>
          ))}
        </>
      )}

      {pinned.length > 0 && (
        <>
          <div className="section-label">Pinned notes</div>
          {pinned.map((n) => (
            <div className="card clickable" key={n.id} onClick={() => openNote(n.id)}>
              <div style={{ fontWeight: 550 }}>📌 {displayTitle(n)}</div>
              <div className="faint">{relativeTime(n.updatedAt)}</div>
            </div>
          ))}
        </>
      )}
    </div>
  );
}
