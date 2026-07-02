import Foundation
import SwiftData
import HermesNotesCore

/// A note: the first-class object the product starts from. Tasks link to
/// notes but are never embedded in them.
@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var title: String
    var markdownBody: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var isArchived: Bool
    /// Optional reminder; rendered as a single quiet glyph, never a banner.
    var reminderAt: Date?

    var tags: [Tag]
    var folder: Folder?
    var notebook: Notebook?
    var project: Project?

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.note)
    var tasks: [TaskItem]

    init(
        id: UUID = UUID(),
        title: String = "",
        markdownBody: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        isPinned: Bool = false,
        isArchived: Bool = false,
        reminderAt: Date? = nil,
        tags: [Tag] = [],
        folder: Folder? = nil,
        notebook: Notebook? = nil,
        project: Project? = nil,
        tasks: [TaskItem] = []
    ) {
        self.id = id
        self.title = title
        self.markdownBody = markdownBody
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.reminderAt = reminderAt
        self.tags = tags
        self.folder = folder
        self.notebook = notebook
        self.project = project
        self.tasks = tasks
    }

    var displayTitle: String {
        title.isEmpty ? "Untitled" : title
    }

    var previewText: String {
        MarkdownParser.plainTextPreview(markdownBody)
    }

    /// Value snapshot for the markdown file mirror and Hermes wiki routing.
    var snapshot: NoteSnapshot {
        NoteSnapshot(
            id: id,
            title: displayTitle,
            markdown: markdownBody,
            createdAt: createdAt,
            updatedAt: updatedAt,
            tags: tags.map(\.name).sorted(),
            folder: folder?.name,
            notebook: notebook?.name,
            project: project?.name,
            isPinned: isPinned,
            isArchived: isArchived,
            linkedTaskIDs: tasks.map(\.id),
            reminderAt: reminderAt
        )
    }
}
