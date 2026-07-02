import SwiftUI
import SwiftData

/// Progressive disclosure home for tags, folder, notebook, project, and the
/// optional reminder. All the power organization lives here, off the main
/// surfaces.
struct NoteOrganizerView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var app
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @Query(sort: \Notebook.name) private var notebooks: [Notebook]
    @Query(sort: \Project.name) private var projects: [Project]

    @State private var newTagName = ""
    @State private var reminderEnabled = false
    @State private var reminderDate = Date.now.addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
                Section("Tags") {
                    ForEach(note.tags, id: \.name) { tag in
                        HStack {
                            Text(tag.name)
                            Spacer()
                            Button {
                                note.tags.removeAll { $0.name == tag.name }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField("Add tag", text: $newTagName)
                            .textInputAutocapitalization(.never)
                            .onSubmit(addTag)
                        Button("Add", action: addTag)
                            .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                Section("Place") {
                    namedPicker("Folder", selection: $note.folder, options: folders, name: \.name) {
                        Folder(name: $0)
                    }
                    namedPicker("Notebook", selection: $note.notebook, options: notebooks, name: \.name) {
                        Notebook(name: $0)
                    }
                    namedPicker("Project", selection: $note.project, options: projects, name: \.name) {
                        Project(name: $0)
                    }
                }

                Section("Reminder") {
                    Toggle("Remind me", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("At", selection: $reminderDate, in: Date.now...)
                    }
                }
            }
            .navigationTitle("Organize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        applyReminder()
                        note.updatedAt = .now
                        app.mirror.mirror(note.snapshot)
                        dismiss()
                    }
                }
            }
            .onAppear {
                reminderEnabled = note.reminderAt != nil
                reminderDate = note.reminderAt ?? Date.now.addingTimeInterval(3600)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty, !note.tags.contains(where: { $0.name == name }) else { return }
        let existing = try? context.fetch(
            FetchDescriptor<Tag>(predicate: #Predicate { $0.name == name })
        ).first
        note.tags.append(existing ?? Tag(name: name))
        newTagName = ""
    }

    private func applyReminder() {
        if reminderEnabled {
            note.reminderAt = reminderDate
            Task {
                await app.reminders.scheduleNoteReminder(
                    noteID: note.id, title: note.displayTitle, at: reminderDate
                )
            }
        } else {
            note.reminderAt = nil
            app.reminders.cancelNoteReminder(noteID: note.id)
        }
    }

    /// Generic "None / existing / New…" picker for folder-like structures.
    @ViewBuilder
    private func namedPicker<T: PersistentModel>(
        _ title: String,
        selection: Binding<T?>,
        options: [T],
        name: KeyPath<T, String>,
        create: @escaping (String) -> T
    ) -> some View {
        NavigationLink {
            NamedItemPicker(title: title, selection: selection, options: options, nameKeyPath: name, create: create)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(selection.wrappedValue?[keyPath: name] ?? "None")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NamedItemPicker<T: PersistentModel>: View {
    let title: String
    @Binding var selection: T?
    let options: [T]
    let nameKeyPath: KeyPath<T, String>
    let create: (String) -> T

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""

    var body: some View {
        List {
            Button {
                selection = nil
                dismiss()
            } label: {
                row(label: "None", selected: selection == nil)
            }
            ForEach(options) { option in
                Button {
                    selection = option
                    dismiss()
                } label: {
                    row(
                        label: option[keyPath: nameKeyPath],
                        selected: selection?.persistentModelID == option.persistentModelID
                    )
                }
            }
            Section {
                HStack {
                    TextField("New \(title.lowercased())", text: $newName)
                    Button("Create") {
                        let item = create(newName.trimmingCharacters(in: .whitespaces))
                        context.insert(item)
                        selection = item
                        dismiss()
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(label: String, selected: Bool) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(CalmTheme.accent)
            }
        }
    }
}
