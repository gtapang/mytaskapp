import Foundation

/// Immutable value representation of a note, used everywhere the note leaves
/// the app's live object graph: the markdown file mirror under the preferred
/// directory, Hermes wiki routing, and tests. The app layer maps its
/// SwiftData `Note` model to and from this type.
public struct NoteSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    public var markdown: String
    public var createdAt: Date
    public var updatedAt: Date
    public var tags: [String]
    public var folder: String?
    public var notebook: String?
    public var project: String?
    public var isPinned: Bool
    public var isArchived: Bool
    public var linkedTaskIDs: [UUID]
    public var reminderAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        markdown: String,
        createdAt: Date,
        updatedAt: Date,
        tags: [String] = [],
        folder: String? = nil,
        notebook: String? = nil,
        project: String? = nil,
        isPinned: Bool = false,
        isArchived: Bool = false,
        linkedTaskIDs: [UUID] = [],
        reminderAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.markdown = markdown
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.folder = folder
        self.notebook = notebook
        self.project = project
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.linkedTaskIDs = linkedTaskIDs
        self.reminderAt = reminderAt
    }
}
