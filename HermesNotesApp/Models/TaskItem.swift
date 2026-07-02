import Foundation
import SwiftData
import HermesNotesCore

/// A task: separate first-class object, tightly linked to at most one source
/// note. Named `TaskItem` to avoid colliding with Swift Concurrency's `Task`.
/// Enum-typed fields are stored as raw strings for schema stability.
@Model
final class TaskItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var statusRaw: String
    var priorityRaw: String
    var quadrantRaw: String
    var dueDate: Date?
    var reminderAt: Date?
    var createdAt: Date
    var updatedAt: Date

    var note: Note?
    var tags: [Tag]
    var project: Project?

    init(
        id: UUID = UUID(),
        title: String,
        status: TaskStatus = .open,
        priority: TaskPriority = .none,
        quadrant: EisenhowerQuadrant = .unassigned,
        dueDate: Date? = nil,
        reminderAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        note: Note? = nil,
        tags: [Tag] = [],
        project: Project? = nil
    ) {
        self.id = id
        self.title = title
        self.statusRaw = status.rawValue
        self.priorityRaw = priority.rawValue
        self.quadrantRaw = quadrant.rawValue
        self.dueDate = dueDate
        self.reminderAt = reminderAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.note = note
        self.tags = tags
        self.project = project
    }

    var status: TaskStatus {
        get { TaskStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var quadrant: EisenhowerQuadrant {
        get { EisenhowerQuadrant(rawValue: quadrantRaw) ?? .unassigned }
        set { quadrantRaw = newValue.rawValue }
    }

    var isDone: Bool { status == .done }

    func isDue(on day: Date, calendar: Calendar = .current) -> Bool {
        guard let dueDate else { return false }
        return calendar.isDate(dueDate, inSameDayAs: day)
    }

    func isOverdue(asOf now: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let dueDate, !status.isTerminal else { return false }
        return dueDate < calendar.startOfDay(for: now)
    }
}
