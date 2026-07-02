import Foundation

/// Encodes a `NoteSnapshot` as a human-readable markdown file with YAML
/// front matter, and decodes it back. This is the on-disk format of the
/// `~/Desktop/M` mirror and the payload format for Hermes wiki routing.
public enum NoteFileCodec {
    // Date.ISO8601FormatStyle is Sendable and portable; ISO8601DateFormatter
    // is neither under Swift 6 strict concurrency.
    private static let iso = Date.ISO8601FormatStyle()

    private static func string(from date: Date) -> String {
        date.formatted(iso)
    }

    private static func date(from string: String) -> Date? {
        try? iso.parse(string)
    }

    public static func encode(_ note: NoteSnapshot) -> String {
        var fields: [(String, FrontMatter.Value)] = [
            ("id", .string(note.id.uuidString)),
            ("title", .string(note.title)),
            ("created", .string(string(from: note.createdAt))),
            ("updated", .string(string(from: note.updatedAt))),
            ("tags", .array(note.tags)),
        ]
        if let folder = note.folder { fields.append(("folder", .string(folder))) }
        if let notebook = note.notebook { fields.append(("notebook", .string(notebook))) }
        if let project = note.project { fields.append(("project", .string(project))) }
        fields.append(("pinned", .bool(note.isPinned)))
        fields.append(("archived", .bool(note.isArchived)))
        if !note.linkedTaskIDs.isEmpty {
            fields.append(("tasks", .array(note.linkedTaskIDs.map(\.uuidString))))
        }
        if let reminder = note.reminderAt {
            fields.append(("reminder", .string(string(from: reminder))))
        }
        return FrontMatter.serialize(fields) + "\n\n" + note.markdown + "\n"
    }

    public static func decode(_ document: String) -> NoteSnapshot? {
        let (fields, body) = FrontMatter.parse(document: document)
        guard let fields,
              case .string(let idString)? = fields["id"],
              let id = UUID(uuidString: idString),
              case .string(let title)? = fields["title"],
              case .string(let createdString)? = fields["created"],
              let created = date(from: createdString),
              case .string(let updatedString)? = fields["updated"],
              let updated = date(from: updatedString)
        else { return nil }

        var note = NoteSnapshot(id: id, title: title, markdown: body, createdAt: created, updatedAt: updated)
        if case .array(let tags)? = fields["tags"] { note.tags = tags }
        if case .string(let folder)? = fields["folder"] { note.folder = folder }
        if case .string(let notebook)? = fields["notebook"] { note.notebook = notebook }
        if case .string(let project)? = fields["project"] { note.project = project }
        if case .bool(let pinned)? = fields["pinned"] { note.isPinned = pinned }
        if case .bool(let archived)? = fields["archived"] { note.isArchived = archived }
        if case .array(let taskIDs)? = fields["tasks"] {
            note.linkedTaskIDs = taskIDs.compactMap(UUID.init(uuidString:))
        }
        if case .string(let reminderString)? = fields["reminder"] {
            note.reminderAt = date(from: reminderString)
        }
        return note
    }
}
