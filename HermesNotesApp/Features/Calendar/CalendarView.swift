import SwiftUI
import SwiftData
import HermesNotesCore

/// Direct in-app calendar: a quiet month grid over a day list that merges
/// system events, tasks due that day, and Hermes-flagged time context.
/// Event creation stays in the system calendar app in v1.
struct CalendarView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.modelContext) private var context

    @Query(filter: #Predicate<TaskItem> { $0.statusRaw != "done" && $0.statusRaw != "dropped" })
    private var openTasks: [TaskItem]

    @Query(filter: #Predicate<HermesContextItem> { !$0.isDismissed })
    private var hermesItems: [HermesContextItem]

    @State private var selectedDay = Date.now
    @State private var displayedMonth = Date.now
    @State private var events: [CalendarService.Event] = []
    @State private var markedDays: Set<Int> = []

    private var calendar: Calendar { .current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    monthGrid

                    VStack(alignment: .leading, spacing: 8) {
                        CalmSectionLabel(selectedDay.formatted(.dateTime.weekday(.wide).month().day()))

                        if app.calendar.accessState == .denied {
                            Text("Calendar access is off. Enable it in Settings to see events here.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .calmCard()
                        }

                        ForEach(events) { event in
                            EventRow(event: event)
                                .contextMenu {
                                    Button("New linked note", systemImage: "note.text.badge.plus") {
                                        createNote(for: event)
                                    }
                                    Button("New linked task", systemImage: "checkmark.circle.badge.questionmark") {
                                        createTask(for: event)
                                    }
                                }
                        }

                        ForEach(tasksDueOnSelectedDay) { task in
                            TodayTaskRow(task: task)
                        }

                        ForEach(hermesForSelectedDay) { item in
                            HermesContextRow(item: item)
                        }

                        if events.isEmpty && tasksDueOnSelectedDay.isEmpty && hermesForSelectedDay.isEmpty {
                            Text("Nothing scheduled.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(CalmTheme.screenPadding)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
            .task {
                await app.calendar.requestAccessIfNeeded()
                refresh()
            }
            .onChange(of: selectedDay) { refresh() }
            .onChange(of: displayedMonth) { refreshMonthMarkers() }
        }
    }

    // MARK: Month grid

    private var monthGrid: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    shiftMonth(-1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    shiftMonth(1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }
            .padding(.horizontal, 4)

            let columns = Array(repeating: GridItem(.flexible()), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                ForEach(monthDays, id: \.self) { day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 32)
                    }
                }
            }
        }
        .calmCard()
    }

    private func dayCell(_ day: Date) -> some View {
        let dayNumber = calendar.component(.day, from: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)
        let hasEvents = markedDays.contains(dayNumber)
        let hasDueTasks = openTasks.contains { $0.isDue(on: day) }

        return Button {
            selectedDay = day
        } label: {
            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isToday ? CalmTheme.accent : .primary))
                HStack(spacing: 2) {
                    if hasEvents {
                        Circle().fill(isSelected ? Color.white : CalmTheme.accent).frame(width: 3, height: 3)
                    }
                    if hasDueTasks {
                        Circle().fill(isSelected ? Color.white : Color.orange).frame(width: 3, height: 3)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? CalmTheme.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Days of the displayed month, padded with nils to align weekday columns.
    private var monthDays: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let dayCount = calendar.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30
        var days: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            days.append(calendar.date(byAdding: .day, value: offset, to: interval.start))
        }
        return days
    }

    // MARK: Day content

    private var tasksDueOnSelectedDay: [TaskItem] {
        openTasks.filter { $0.isDue(on: selectedDay) }
    }

    private var hermesForSelectedDay: [HermesContextItem] {
        hermesItems.filter { item in
            guard let occursAt = item.occursAt else { return false }
            return calendar.isDate(occursAt, inSameDayAs: selectedDay)
        }
    }

    // MARK: Actions

    private func createNote(for event: CalendarService.Event) {
        let note = Note(
            title: event.title,
            markdownBody: "Notes for \(event.title) — \(event.start.formatted(.dateTime.month().day().hour().minute()))\n\n"
        )
        context.insert(note)
        app.mirror.mirror(note.snapshot)
    }

    private func createTask(for event: CalendarService.Event) {
        context.insert(TaskItem(
            title: "Prepare: \(event.title)",
            dueDate: calendar.startOfDay(for: event.start)
        ))
    }

    private func shiftMonth(_ delta: Int) {
        if let shifted = calendar.date(byAdding: .month, value: delta, to: displayedMonth) {
            displayedMonth = shifted
        }
    }

    private func refresh() {
        events = app.calendar.events(on: selectedDay)
        refreshMonthMarkers()
    }

    private func refreshMonthMarkers() {
        markedDays = app.calendar.daysWithEvents(inMonthOf: displayedMonth)
    }
}
