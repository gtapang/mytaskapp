import SwiftUI
import SwiftData
import HermesNotesCore

/// Task home: filter and group without dashboard density. Each task opens a
/// small detail sheet for dates, priority, quadrant, and note linking.
struct TasksView: View {
    private enum Grouping: String, CaseIterable {
        case date = "By date"
        case project = "By project"
    }

    @Environment(\.modelContext) private var context

    @Query(sort: \TaskItem.createdAt, order: .reverse)
    private var allTasks: [TaskItem]

    @State private var grouping: Grouping = .date
    @State private var showCompleted = false
    @State private var editingTask: TaskItem?
    @State private var newTaskTitle = ""

    private var visibleTasks: [TaskItem] {
        allTasks.filter { showCompleted || !$0.status.isTerminal }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("New task", text: $newTaskTitle)
                            .onSubmit(addTask)
                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(CalmTheme.accent)
                        }
                        .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                ForEach(groups, id: \.title) { group in
                    Section {
                        ForEach(group.tasks) { task in
                            TaskListRow(task: task) { editingTask = task }
                        }
                    } header: {
                        CalmSectionLabel(group.title)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Picker("Group", selection: $grouping) {
                            ForEach(Grouping.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        Toggle("Show completed", isOn: $showCompleted)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .sheet(item: $editingTask) { task in
                TaskDetailSheet(task: task)
            }
            .overlay {
                if visibleTasks.isEmpty {
                    ContentUnavailableView(
                        "No open tasks",
                        systemImage: "checkmark.circle",
                        description: Text("Tasks you create or extract from notes land here.")
                    )
                }
            }
        }
    }

    private struct TaskGroup {
        var title: String
        var tasks: [TaskItem]
    }

    private var groups: [TaskGroup] {
        switch grouping {
        case .date:
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: .now)
            var overdue: [TaskItem] = [], dueToday: [TaskItem] = []
            var upcoming: [TaskItem] = [], someday: [TaskItem] = []
            for task in visibleTasks {
                if task.isOverdue() {
                    overdue.append(task)
                } else if task.isDue(on: .now) {
                    dueToday.append(task)
                } else if let due = task.dueDate, due > today {
                    upcoming.append(task)
                } else {
                    someday.append(task)
                }
            }
            upcoming.sort { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
            return [
                TaskGroup(title: "Overdue", tasks: overdue),
                TaskGroup(title: "Today", tasks: dueToday),
                TaskGroup(title: "Upcoming", tasks: upcoming),
                TaskGroup(title: "Someday", tasks: someday),
            ].filter { !$0.tasks.isEmpty }
        case .project:
            let grouped = Dictionary(grouping: visibleTasks) { $0.project?.name ?? "No project" }
            return grouped
                .map { TaskGroup(title: $0.key, tasks: $0.value) }
                .sorted { $0.title < $1.title }
        }
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        context.insert(TaskItem(title: title))
        newTaskTitle = ""
    }
}

struct TaskListRow: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    var onEdit: () -> Void

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
                HStack(spacing: 6) {
                    if let due = task.dueDate {
                        Text(due, format: .dateTime.month(.abbreviated).day())
                            .foregroundStyle(task.isOverdue() ? .red : .secondary)
                    }
                    if let note = task.note {
                        Label(note.displayTitle, systemImage: "note.text")
                            .lineLimit(1)
                    }
                    if task.quadrant != .unassigned {
                        Text(quadrantShortName(task.quadrant))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()
            ReminderGlyph(date: task.reminderAt)
            if task.priority != .none {
                Circle()
                    .fill(CalmTheme.priorityColor(task.priority))
                    .frame(width: 7, height: 7)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                app.reminders.cancelTaskReminder(taskID: task.id)
                context.delete(task)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

func quadrantShortName(_ quadrant: EisenhowerQuadrant) -> String {
    switch quadrant {
    case .doFirst: "Do first"
    case .schedule: "Schedule"
    case .delegate: "Delegate"
    case .eliminate: "Eliminate"
    case .unassigned: ""
    }
}

/// Small focused editor for one task.
struct TaskDetailSheet: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var dueEnabled = false
    @State private var dueDate = Date.now
    @State private var reminderEnabled = false
    @State private var reminderDate = Date.now.addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $task.title)
                    Picker("Status", selection: $task.status) {
                        Text("Open").tag(TaskStatus.open)
                        Text("In progress").tag(TaskStatus.inProgress)
                        Text("Done").tag(TaskStatus.done)
                        Text("Dropped").tag(TaskStatus.dropped)
                    }
                }

                Section("Schedule") {
                    Toggle("Due date", isOn: $dueEnabled)
                    if dueEnabled {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                    Toggle("Reminder", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("At", selection: $reminderDate, in: Date.now...)
                    }
                }

                Section("Planning") {
                    Picker("Priority", selection: $task.priority) {
                        Text("None").tag(TaskPriority.none)
                        Text("Low").tag(TaskPriority.low)
                        Text("Medium").tag(TaskPriority.medium)
                        Text("High").tag(TaskPriority.high)
                    }
                    Picker("Quadrant", selection: $task.quadrant) {
                        Text("Unassigned").tag(EisenhowerQuadrant.unassigned)
                        ForEach(EisenhowerQuadrant.matrix, id: \.self) { quadrant in
                            Text(quadrantShortName(quadrant)).tag(quadrant)
                        }
                    }
                    Picker("Project", selection: $task.project) {
                        Text("None").tag(Project?.none)
                        ForEach(projects) { project in
                            Text(project.name).tag(Project?.some(project))
                        }
                    }
                }

                Section("Linked note") {
                    Picker("Note", selection: $task.note) {
                        Text("None").tag(Note?.none)
                        ForEach(notes.prefix(30)) { note in
                            Text(note.displayTitle).tag(Note?.some(note))
                        }
                    }
                }
            }
            .navigationTitle("Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        apply()
                        dismiss()
                    }
                }
            }
            .onAppear {
                dueEnabled = task.dueDate != nil
                dueDate = task.dueDate ?? .now
                reminderEnabled = task.reminderAt != nil
                reminderDate = task.reminderAt ?? Date.now.addingTimeInterval(3600)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func apply() {
        task.dueDate = dueEnabled ? dueDate : nil
        task.updatedAt = .now
        if reminderEnabled {
            task.reminderAt = reminderDate
            Task {
                await app.reminders.scheduleTaskReminder(
                    taskID: task.id, title: task.title, at: reminderDate
                )
            }
        } else {
            task.reminderAt = nil
            app.reminders.cancelTaskReminder(taskID: task.id)
        }
    }
}
