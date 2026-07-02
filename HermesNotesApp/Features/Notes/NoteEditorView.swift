import SwiftUI
import SwiftData
import HermesNotesCore

/// Markdown editing with a readable preview one tap away. AI assists and
/// Hermes actions live behind single toolbar menus — present when wanted,
/// invisible otherwise.
struct NoteEditorView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app

    private enum Mode: String, CaseIterable {
        case edit = "Edit"
        case preview = "Read"
    }

    @State private var mode: Mode = .edit
    @State private var isOrganizerPresented = false
    @State private var summary: String?
    @State private var suggestedTags: [String] = []
    @State private var extractedTasks: [ExtractedTaskSuggestion] = []
    @State private var isTaskReviewPresented = false
    @State private var isWorking = false
    @State private var hermesConfirmation: String?

    var body: some View {
        VStack(spacing: 0) {
            TextField("Title", text: $note.title, axis: .vertical)
                .font(.title3.weight(.semibold))
                .textFieldStyle(.plain)
                .padding(.horizontal, CalmTheme.screenPadding)
                .padding(.top, 8)
                .onChange(of: note.title) { touch() }

            if let summary {
                summaryBanner(summary)
            }

            if !suggestedTags.isEmpty {
                tagSuggestionRow
            }

            Group {
                switch mode {
                case .edit:
                    TextEditor(text: $note.markdownBody)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, CalmTheme.screenPadding - 4)
                        .onChange(of: note.markdownBody) { touch() }
                case .preview:
                    MarkdownPreview(markdown: note.markdownBody)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !note.tasks.isEmpty {
                linkedTasksBar
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { editorToolbar }
        .sheet(isPresented: $isOrganizerPresented) {
            NoteOrganizerView(note: note)
        }
        .sheet(isPresented: $isTaskReviewPresented) {
            ExtractedTasksReview(note: note, suggestions: extractedTasks)
        }
        .onDisappear {
            if note.title.isEmpty && note.markdownBody.isEmpty && note.tasks.isEmpty {
                context.delete(note) // never keep accidental empties
            } else {
                app.mirror.mirror(note.snapshot)
            }
        }
        .alert(
            "Sent to Hermes",
            isPresented: Binding(
                get: { hermesConfirmation != nil },
                set: { if !$0 { hermesConfirmation = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(hermesConfirmation ?? "")
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .frame(width: 150)
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if app.intelligence.isAvailable || !note.markdownBody.isEmpty {
                Menu {
                    Button("Summarize", systemImage: "text.alignleft") { runSummarize() }
                    Button("Suggest tags", systemImage: "tag") { runTagSuggestion() }
                    Button("Extract tasks", systemImage: "checklist") { runTaskExtraction() }
                } label: {
                    if isWorking {
                        ProgressView()
                    } else {
                        Image(systemName: "sparkles")
                    }
                }
                .accessibilityLabel("AI assists")
                .disabled(isWorking || note.markdownBody.isEmpty)
            }

            Menu {
                Button("Route to wiki", systemImage: "books.vertical") {
                    Task {
                        app.mirror.mirror(note.snapshot)
                        await app.hermes.routeToWiki(note.snapshot)
                        hermesConfirmation = "Queued for the wiki workflow."
                    }
                }
                Button("Send via Telegram", systemImage: "paperplane") {
                    Task {
                        await app.hermes.pushToTelegram(
                            text: "\(note.displayTitle)\n\n\(note.markdownBody)"
                        )
                        hermesConfirmation = "Queued for Telegram."
                    }
                }
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .accessibilityLabel("Hermes actions")
            .disabled(!app.hermes.isConfigured)

            Menu {
                Button(note.isPinned ? "Unpin" : "Pin", systemImage: "pin") {
                    note.isPinned.toggle()
                    touch()
                }
                Button("Organize…", systemImage: "folder") {
                    isOrganizerPresented = true
                }
                Button(note.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") {
                    note.isArchived.toggle()
                    touch()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: AI assists

    private func runSummarize() {
        run {
            summary = try await app.intelligence.summarize(note.markdownBody)
        }
    }

    private func runTagSuggestion() {
        run {
            let existing = (try? context.fetch(FetchDescriptor<Tag>()))?.map(\.name) ?? []
            let current = Set(note.tags.map(\.name))
            suggestedTags = try await app.intelligence
                .suggestTags(for: note.markdownBody, existing: existing)
                .filter { !current.contains($0) }
        }
    }

    private func runTaskExtraction() {
        run {
            extractedTasks = try await app.intelligence.extractTasks(from: note.markdownBody)
            isTaskReviewPresented = !extractedTasks.isEmpty
        }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        isWorking = true
        Task {
            defer { isWorking = false }
            try? await work()
        }
    }

    // MARK: Subviews

    private func summaryBanner(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
                .foregroundStyle(CalmTheme.accent)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                summary = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(CalmTheme.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, CalmTheme.screenPadding)
        .padding(.top, 6)
    }

    private var tagSuggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestedTags, id: \.self) { name in
                    Button {
                        addTag(named: name)
                        suggestedTags.removeAll { $0 == name }
                    } label: {
                        Label(name, systemImage: "plus")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(CalmTheme.accent.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button("Dismiss") { suggestedTags = [] }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, CalmTheme.screenPadding)
        }
        .padding(.top, 6)
    }

    private var linkedTasksBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            CalmSectionLabel("Linked tasks")
            ForEach(note.tasks) { task in
                TodayTaskRow(task: task)
            }
        }
        .padding(CalmTheme.screenPadding)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Helpers

    private func addTag(named name: String) {
        let existing = try? context.fetch(
            FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
        ).first
        note.tags.append(existing ?? Tag(name: name))
        touch()
    }

    private func touch() {
        note.updatedAt = .now
    }
}

/// Review sheet for extracted tasks: nothing becomes a TaskItem until the
/// user confirms.
struct ExtractedTasksReview: View {
    let note: Note
    @State var suggestions: [ExtractedTaskSuggestion]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(suggestions) { suggestion in
                Button {
                    if selected.contains(suggestion.id) {
                        selected.remove(suggestion.id)
                    } else {
                        selected.insert(suggestion.id)
                    }
                } label: {
                    HStack {
                        Image(systemName: selected.contains(suggestion.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected.contains(suggestion.id) ? CalmTheme.accent : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                            if let hint = suggestion.dueHint {
                                Text(hint)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Extracted tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(selected.count)") {
                        for suggestion in suggestions where selected.contains(suggestion.id) {
                            context.insert(TaskItem(
                                title: suggestion.title,
                                priority: suggestion.priority,
                                note: note
                            ))
                        }
                        dismiss()
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .onAppear { selected = Set(suggestions.map(\.id)) }
        }
        .presentationDetents([.medium])
    }
}
