import Foundation
import SwiftData

/// Secondary organization structures. They exist for power organization but
/// stay behind progressive disclosure — none of them add chrome to the
/// default note list.

@Model
final class Tag {
    @Attribute(.unique) var name: String

    @Relationship(deleteRule: .nullify, inverse: \Note.tags)
    var notes: [Note]

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.tags)
    var tasks: [TaskItem]

    init(name: String, notes: [Note] = [], tasks: [TaskItem] = []) {
        self.name = name
        self.notes = notes
        self.tasks = tasks
    }
}

@Model
final class Folder {
    @Attribute(.unique) var name: String

    @Relationship(deleteRule: .nullify, inverse: \Note.folder)
    var notes: [Note]

    init(name: String, notes: [Note] = []) {
        self.name = name
        self.notes = notes
    }
}

@Model
final class Notebook {
    @Attribute(.unique) var name: String

    @Relationship(deleteRule: .nullify, inverse: \Note.notebook)
    var notes: [Note]

    init(name: String, notes: [Note] = []) {
        self.name = name
        self.notes = notes
    }
}

@Model
final class Project {
    @Attribute(.unique) var name: String
    var details: String
    var isActive: Bool

    @Relationship(deleteRule: .nullify, inverse: \Note.project)
    var notes: [Note]

    @Relationship(deleteRule: .nullify, inverse: \TaskItem.project)
    var tasks: [TaskItem]

    init(name: String, details: String = "", isActive: Bool = true, notes: [Note] = [], tasks: [TaskItem] = []) {
        self.name = name
        self.details = details
        self.isActive = isActive
        self.notes = notes
        self.tasks = tasks
    }
}
