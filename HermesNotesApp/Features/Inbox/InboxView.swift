import SwiftUI
import SwiftData
import HermesNotesCore

/// Processing surface for captured thoughts — local quick captures and
/// Telegram captures arriving through Hermes. Each item becomes a note, a
/// task, or both; the on-device classifier suggests which, never decides.
struct InboxView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app

    @Query(sort: \InboxItem.createdAt, order: .reverse)
    private var items: [InboxItem]

    @State private var showProcessed = false

    private var visibleItems: [InboxItem] {
        items.filter { $0.isProcessed == showProcessed }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleItems) { item in
                    InboxItemRow(item: item)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Toggle("Show processed", isOn: $showProcessed)
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
            .refreshable {
                await app.hermes.syncNow(context: context)
            }
            .overlay {
                if visibleItems.isEmpty {
                    ContentUnavailableView(
                        showProcessed ? "Nothing processed yet" : "Inbox zero",
                        systemImage: "tray",
                        description: Text(showProcessed ? "" : "Captures from here and Telegram land in this list.")
                    )
                }
            }
        }
    }
}

private struct InboxItemRow: View {
    @Bindable var item: InboxItem
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: item.source == .telegram ? "paperplane" : "tray.and.arrow.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.createdAt, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if item.suggestedKind != .unknown {
                    Text(suggestionLabel)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(CalmTheme.accent.opacity(0.1), in: Capsule())
                        .foregroundStyle(CalmTheme.accent)
                }
            }

            Text(item.rawContent)
                .font(.body)
                .lineLimit(4)

            if !item.isProcessed {
                HStack(spacing: 10) {
                    Button("Note") { convert(toNote: true, toTask: false) }
                    Button("Task") { convert(toNote: false, toTask: true) }
                    Button("Both") { convert(toNote: true, toTask: true) }
                    Spacer()
                    Button {
                        item.isProcessed = true
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Mark processed")
                }
                .font(.footnote.weight(.medium))
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(CalmTheme.accent)
            }
        }
        .padding(.vertical, 4)
        .task {
            // Classify once, on device, only while unprocessed.
            if item.suggestedKind == .unknown && !item.isProcessed && app.intelligence.isAvailable {
                if let kind = try? await app.intelligence.classify(inboxText: item.rawContent) {
                    item.suggestedKind = kind
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var suggestionLabel: String {
        switch item.suggestedKind {
        case .note: "Looks like a note"
        case .task: "Looks like a task"
        case .noteAndTask: "Note + task"
        case .reference: "Reference"
        case .unknown: ""
        }
    }

    private func convert(toNote: Bool, toTask: Bool) {
        let lines = item.rawContent.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: true)
        let title = String(lines.first ?? "Captured item").prefix(80)
        let body = lines.count > 1 ? String(lines[1]) : ""

        var note: Note?
        if toNote {
            let newNote = Note(title: String(title), markdownBody: body)
            context.insert(newNote)
            item.resultingNoteID = newNote.id
            app.mirror.mirror(newNote.snapshot)
            note = newNote
        }
        if toTask {
            let task = TaskItem(title: String(title), note: note)
            context.insert(task)
            item.resultingTaskID = task.id
        }
        item.isProcessed = true

        // Close the loop for Telegram captures: confirm back through Hermes.
        if item.source == .telegram, let sourceID = item.sourceID {
            let made = [toNote ? "note" : nil, toTask ? "task" : nil].compactMap { $0 }.joined(separator: " + ")
            Task {
                await app.hermes.pushToTelegram(
                    text: "Filed as \(made): \(title)",
                    replyToCaptureID: sourceID
                )
            }
        }
    }
}
