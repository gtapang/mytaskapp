import SwiftUI
import SwiftData
import HermesNotesCore

/// The default landing screen: a calm day starter. One briefing, today's
/// tasks and events, anything important Hermes surfaced, a few relevant
/// notes, and a quick capture entry point. Nothing else.
struct TodayView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<TaskItem> { $0.statusRaw != "done" && $0.statusRaw != "dropped" })
    private var openTasks: [TaskItem]

    @Query(filter: #Predicate<Note> { $0.isPinned && !$0.isArchived })
    private var pinnedNotes: [Note]

    @Query(filter: #Predicate<InboxItem> { !$0.isProcessed })
    private var unprocessedInbox: [InboxItem]

    @Query(filter: #Predicate<HermesContextItem> { !$0.isDismissed },
           sort: \HermesContextItem.importance, order: .reverse)
    private var hermesItems: [HermesContextItem]

    @State private var briefing: String = ""
    @State private var todaysEvents: [CalendarService.Event] = []
    @State private var isSettingsPresented = false

    private var dueTasks: [TaskItem] {
        openTasks
            .filter { $0.isDue(on: .now) || $0.isOverdue() }
            .sorted { ($0.isOverdue() ? 0 : 1, $1.priority) < ($1.isOverdue() ? 0 : 1, $0.priority) }
    }

    private var upcomingReminders: [TaskItem] {
        openTasks
            .filter { ($0.reminderAt ?? .distantPast) >= .now }
            .sorted { ($0.reminderAt ?? .distantFuture) < ($1.reminderAt ?? .distantFuture) }
            .prefix(3)
            .map { $0 }
    }

    private var hermesHighlights: [HermesContextItem] {
        Array(hermesItems.prefix(4))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    briefingCard

                    if !dueTasks.isEmpty {
                        section("Due today") {
                            ForEach(dueTasks) { task in
                                TodayTaskRow(task: task)
                            }
                        }
                    }

                    if !todaysEvents.isEmpty {
                        section("Calendar") {
                            ForEach(todaysEvents) { event in
                                EventRow(event: event)
                            }
                        }
                    }

                    if !hermesHighlights.isEmpty {
                        section("Important, via Hermes") {
                            ForEach(hermesHighlights) { item in
                                HermesContextRow(item: item)
                            }
                        }
                    }

                    if !upcomingReminders.isEmpty {
                        section("Reminders") {
                            ForEach(upcomingReminders) { task in
                                HStack {
                                    Image(systemName: "bell")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(task.title)
                                    Spacer()
                                    if let at = task.reminderAt {
                                        Text(at, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .calmCard()
                            }
                        }
                    }

                    if !pinnedNotes.isEmpty {
                        section("Pinned notes") {
                            ForEach(pinnedNotes.prefix(3)) { note in
                                NavigationLink(value: note.id) {
                                    NoteRow(note: note)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(CalmTheme.screenPadding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: UUID.self) { noteID in
                NoteEditorDestination(noteID: noteID)
            }
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        isSettingsPresented = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        app.isQuickCapturePresented = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Quick capture")
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
            .task {
                await app.calendar.requestAccessIfNeeded()
                todaysEvents = app.calendar.events(on: .now)
                briefing = await app.intelligence.dayStartBriefing(for: digest())
            }
            .refreshable {
                await app.hermes.syncNow(context: context)
                todaysEvents = app.calendar.events(on: .now)
                briefing = await app.intelligence.dayStartBriefing(for: digest())
            }
        }
    }

    private var briefingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CalmSectionLabel("Day start")
            Text(briefing.isEmpty ? "Gathering your day…" : briefing)
                .font(.body)
                .lineSpacing(3)
            if !unprocessedInbox.isEmpty {
                Button {
                    app.selectedScreen = .inbox
                } label: {
                    Text("\(unprocessedInbox.count) item\(unprocessedInbox.count == 1 ? "" : "s") waiting in Inbox")
                        .font(.footnote)
                        .foregroundStyle(CalmTheme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .calmCard()
        .calmGrain()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            CalmSectionLabel(title)
            content()
        }
    }

    private func digest() -> DayStartDigest {
        DayStartDigest(
            date: .now,
            dueTasks: dueTasks.map {
                .init(title: $0.title, priority: $0.priority, quadrant: $0.quadrant, isOverdue: $0.isOverdue())
            },
            events: todaysEvents.map {
                .init(title: $0.title, start: $0.start, isAllDay: $0.isAllDay)
            },
            hermesHighlights: hermesHighlights.map {
                HermesContextPayload(
                    id: $0.sourceID,
                    kind: $0.kind,
                    title: $0.title,
                    summary: $0.summary,
                    importance: $0.importance,
                    ruleHit: $0.ruleHit,
                    occursAt: $0.occursAt
                )
            },
            inboxCount: unprocessedInbox.count
        )
    }
}

// MARK: - Rows shared by Today and Calendar

struct TodayTaskRow: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Button {
                task.status = task.isDone ? .open : .done
                task.updatedAt = .now
                if task.isDone {
                    app.reminders.cancelTaskReminder(taskID: task.id)
                }
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? CalmTheme.accent : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isDone, color: .secondary)
                if task.isOverdue() {
                    Text("Overdue")
                        .font(.caption2)
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
            Spacer()
            ReminderGlyph(date: task.reminderAt)
            if task.priority != .none {
                Circle()
                    .fill(CalmTheme.priorityColor(task.priority))
                    .frame(width: 7, height: 7)
            }
        }
        .calmCard()
    }
}

struct EventRow: View {
    let event: CalendarService.Event

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                if event.isAllDay {
                    Text("All day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(event.start, style: .time)
                        .font(.caption.weight(.medium))
                    Text(event.end, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 52, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(CalmTheme.accent.opacity(0.6))
                .frame(width: 3, height: 28)

            Text(event.title)
            Spacer()
        }
        .calmCard()
    }
}

struct HermesContextRow: View {
    @Bindable var item: HermesContextItem

    private var icon: String {
        switch item.kind {
        case .email: "envelope"
        case .calendar: "calendar.badge.exclamationmark"
        case .summary: "sparkles"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(CalmTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                Text(item.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .calmCard()
        .contextMenu {
            Button("Dismiss") { item.isDismissed = true }
        }
    }
}
