import SwiftUI
import SwiftData

/// The notes home: search, pinned, then everything recent. Organization
/// (tags, folders, notebooks, projects) lives inside each note's organizer
/// sheet — the list itself stays quiet.
struct NotesListView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app

    @Query(sort: \Note.updatedAt, order: .reverse)
    private var notes: [Note]

    @State private var searchText = ""
    @State private var showArchived = false
    @State private var path: [UUID] = []

    private var visibleNotes: [Note] {
        notes.filter { note in
            note.isArchived == showArchived && (
                searchText.isEmpty
                || note.title.localizedCaseInsensitiveContains(searchText)
                || note.markdownBody.localizedCaseInsensitiveContains(searchText)
                || note.tags.contains { $0.name.localizedCaseInsensitiveContains(searchText) }
            )
        }
    }

    private var pinned: [Note] { visibleNotes.filter(\.isPinned) }
    private var unpinned: [Note] { visibleNotes.filter { !$0.isPinned } }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if !pinned.isEmpty {
                    Section {
                        ForEach(pinned) { note in
                            noteLink(note)
                        }
                    } header: {
                        CalmSectionLabel("Pinned")
                    }
                }
                Section {
                    ForEach(unpinned) { note in
                        noteLink(note)
                    }
                } header: {
                    if !pinned.isEmpty || showArchived {
                        CalmSectionLabel(showArchived ? "Archived" : "Notes")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search notes")
            .navigationTitle(showArchived ? "Archive" : "Notes")
            .navigationDestination(for: UUID.self) { noteID in
                NoteEditorDestination(noteID: noteID)
            }
            .toolbar {
                ToolbarItem(placement: .secondaryAction) {
                    Toggle("Show archive", systemImage: "archivebox", isOn: $showArchived)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createNote()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New note")
                }
            }
            .overlay {
                if visibleNotes.isEmpty {
                    ContentUnavailableView(
                        showArchived ? "No archived notes" : "No notes yet",
                        systemImage: "note.text",
                        description: Text(showArchived ? "" : "Capture something with the pencil above.")
                    )
                }
            }
        }
    }

    private func noteLink(_ note: Note) -> some View {
        NavigationLink(value: note.id) {
            NoteRow(note: note)
        }
        .swipeActions(edge: .leading) {
            Button {
                note.isPinned.toggle()
            } label: {
                Label(note.isPinned ? "Unpin" : "Pin", systemImage: "pin")
            }
            .tint(CalmTheme.accent)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                app.mirror.remove(noteID: note.id)
                app.reminders.cancelNoteReminder(noteID: note.id)
                context.delete(note)
            } label: {
                Label("Delete", systemImage: "trash")
            }
            Button {
                note.isArchived.toggle()
                note.updatedAt = .now
                app.mirror.mirror(note.snapshot)
            } label: {
                Label(note.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox")
            }
        }
    }

    private func createNote() {
        let note = Note()
        context.insert(note)
        path.append(note.id)
    }
}

/// Compact note row: title, one-line preview, quiet metadata.
struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(CalmTheme.accent)
                }
                Text(note.displayTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Spacer()
                ReminderGlyph(date: note.reminderAt)
            }
            if !note.previewText.isEmpty {
                Text(note.previewText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 6) {
                Text(note.updatedAt, format: .relative(presentation: .named))
                if !note.tasks.isEmpty {
                    Text("· \(note.tasks.count) task\(note.tasks.count == 1 ? "" : "s")")
                }
                if let notebook = note.notebook {
                    Text("· \(notebook.name)")
                }
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

/// Resolves a note id (from navigation values or App Intent deep links) to
/// the live editor.
struct NoteEditorDestination: View {
    @Environment(\.modelContext) private var context
    let noteID: UUID

    var body: some View {
        if let note = try? context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { $0.id == noteID })
        ).first {
            NoteEditorView(note: note)
        } else {
            ContentUnavailableView("Note not found", systemImage: "questionmark.circle")
        }
    }
}
