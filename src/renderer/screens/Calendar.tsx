import { useEffect, useState } from 'react';
import { isDueOn, isTerminal } from '../../core/types';
import type { CalendarEvent } from '../../shared/api';
import { TaskRow } from '../components/TaskRow';
import { api, newNote, newTask, todayISO, useApp } from '../state';

const pad = (n: number) => String(n).padStart(2, '0');
const dayKey = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;

/**
 * Direct in-app calendar: a quiet month grid over a day list that merges ICS
 * feed events, tasks due that day, and Hermes-flagged time context.
 */
export function Calendar() {
  const { data, refresh } = useApp();
  const [selectedDay, setSelectedDay] = useState(todayISO());
  const [displayedMonth, setDisplayedMonth] = useState(() => {
    const now = new Date();
    return new Date(now.getFullYear(), now.getMonth(), 1);
  });
  const [events, setEvents] = useState<CalendarEvent[]>([]);
  const [monthMarks, setMonthMarks] = useState<Set<string>>(new Set());

  useEffect(() => {
    let cancelled = false;
    void api.calendarEvents(selectedDay).then((e) => {
      if (!cancelled) setEvents(e);
    });
    return () => {
      cancelled = true;
    };
  }, [selectedDay, data.settings.icsFeeds.join(',')]);

  // Event dots for the month grid: one lookup per visible day, cached by the
  // main process's feed cache so this stays cheap.
  useEffect(() => {
    let cancelled = false;
    (async () => {
      const marks = new Set<string>();
      const days = monthDays(displayedMonth).filter((d): d is Date => d !== null);
      await Promise.all(
        days.map(async (d) => {
          const dayEvents = await api.calendarEvents(dayKey(d));
          if (dayEvents.length > 0) marks.add(dayKey(d));
        })
      );
      if (!cancelled) setMonthMarks(marks);
    })();
    return () => {
      cancelled = true;
    };
  }, [displayedMonth, data.settings.icsFeeds.join(',')]);

  const openTasks = data.tasks.filter((t) => !isTerminal(t.status));
  const dueSelected = openTasks.filter((t) => isDueOn(t, selectedDay));
  const hermesSelected = data.hermesContext.filter(
    (c) => !c.dismissed && c.occursAt && c.occursAt.slice(0, 10) === selectedDay
  );

  const shiftMonth = (delta: number) =>
    setDisplayedMonth((m) => new Date(m.getFullYear(), m.getMonth() + delta, 1));

  const createLinkedNote = async (event: CalendarEvent) => {
    await api.saveNote(
      newNote({
        title: event.title,
        markdown: `Notes for ${event.title} — ${selectedDay}\n\n`,
      })
    );
    await refresh();
  };

  const createLinkedTask = async (event: CalendarEvent) => {
    await api.saveTask(newTask(`Prepare: ${event.title}`, { dueDate: selectedDay }));
    await refresh();
  };

  const days = monthDays(displayedMonth);
  const today = todayISO();

  return (
    <div className="screen">
      <h1>Calendar</h1>

      <div className="card">
        <div className="row" style={{ alignItems: 'center', marginBottom: 8 }}>
          <button className="quiet" onClick={() => shiftMonth(-1)}>
            ‹
          </button>
          <div className="grow" style={{ textAlign: 'center', fontWeight: 600 }}>
            {displayedMonth.toLocaleDateString(undefined, { month: 'long', year: 'numeric' })}
          </div>
          <button className="quiet" onClick={() => shiftMonth(1)}>
            ›
          </button>
        </div>
        <div className="month-grid">
          {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d, i) => (
            <div className="dow" key={i}>
              {d}
            </div>
          ))}
          {days.map((day, i) =>
            day === null ? (
              <div key={`pad-${i}`} />
            ) : (
              <button
                key={dayKey(day)}
                className={[
                  'day',
                  dayKey(day) === selectedDay ? 'selected' : '',
                  dayKey(day) === today ? 'today' : '',
                ].join(' ')}
                onClick={() => setSelectedDay(dayKey(day))}
              >
                {day.getDate()}
                <div className="marks">
                  {monthMarks.has(dayKey(day)) && <i />}
                  {openTasks.some((t) => isDueOn(t, dayKey(day))) && <i className="task-mark" />}
                </div>
              </button>
            )
          )}
        </div>
      </div>

      <div className="section-label">
        {new Date(selectedDay + 'T00:00:00').toLocaleDateString(undefined, {
          weekday: 'long',
          month: 'long',
          day: 'numeric',
        })}
      </div>

      {data.settings.icsFeeds.length === 0 && (
        <div className="faint" style={{ marginBottom: 8 }}>
          No calendar feeds yet — add an ICS URL in Settings to see events here.
        </div>
      )}

      {events.map((event) => (
        <div className="card row" key={event.id} style={{ alignItems: 'center' }}>
          <span className="faint" style={{ width: 56 }}>
            {event.allDay
              ? 'All day'
              : new Date(event.startISO).toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
          </span>
          <span style={{ width: 3, height: 26, background: 'var(--accent)', borderRadius: 2, opacity: 0.6 }} />
          <span className="grow">{event.title}</span>
          <button className="quiet" title="New linked note" onClick={() => createLinkedNote(event)}>
            +📝
          </button>
          <button className="quiet" title="New linked task" onClick={() => createLinkedTask(event)}>
            +✓
          </button>
        </div>
      ))}

      {dueSelected.map((t) => (
        <TaskRow key={t.id} task={t} />
      ))}

      {hermesSelected.map((h) => (
        <div className="card row" key={h.sourceId}>
          <span>✦</span>
          <div className="grow">
            <div style={{ fontWeight: 550 }}>{h.title}</div>
            <div className="faint">{h.summary}</div>
          </div>
        </div>
      ))}

      {events.length === 0 && dueSelected.length === 0 && hermesSelected.length === 0 && (
        <div className="faint">Nothing scheduled.</div>
      )}
    </div>
  );
}

/** Days of the displayed month, padded with nulls to align weekday columns (Sunday first). */
function monthDays(month: Date): Array<Date | null> {
  const first = new Date(month.getFullYear(), month.getMonth(), 1);
  const leading = first.getDay();
  const count = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate();
  const days: Array<Date | null> = Array.from({ length: leading }, () => null);
  for (let d = 1; d <= count; d += 1) {
    days.push(new Date(month.getFullYear(), month.getMonth(), d));
  }
  return days;
}
