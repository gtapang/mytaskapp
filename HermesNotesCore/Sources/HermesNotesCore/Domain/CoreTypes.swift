import Foundation

/// Status of a task. Raw values are stable identifiers used in persistence
/// and in the markdown mirror; never rename them without a migration.
public enum TaskStatus: String, Codable, CaseIterable, Sendable {
    case open
    case inProgress = "in_progress"
    case done
    case dropped

    public var isTerminal: Bool { self == .done || self == .dropped }
}

public enum TaskPriority: String, Codable, CaseIterable, Sendable, Comparable {
    case none
    case low
    case medium
    case high

    private var rank: Int {
        switch self {
        case .none: 0
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

/// Eisenhower quadrant. `unassigned` keeps the matrix optional: tasks only
/// appear on the planning screen once the user (or an AI suggestion the user
/// accepts) places them.
public enum EisenhowerQuadrant: String, Codable, CaseIterable, Sendable {
    case doFirst = "urgent_important"
    case schedule = "important_not_urgent"
    case delegate = "urgent_not_important"
    case eliminate = "not_urgent_not_important"
    case unassigned

    public init(urgent: Bool, important: Bool) {
        switch (urgent, important) {
        case (true, true): self = .doFirst
        case (false, true): self = .schedule
        case (true, false): self = .delegate
        case (false, false): self = .eliminate
        }
    }

    public var isUrgent: Bool { self == .doFirst || self == .delegate }
    public var isImportant: Bool { self == .doFirst || self == .schedule }

    /// The four plannable quadrants in canonical display order.
    public static let matrix: [EisenhowerQuadrant] = [.doFirst, .schedule, .delegate, .eliminate]
}

public enum InboxSource: String, Codable, CaseIterable, Sendable {
    case localCapture = "local_capture"
    case telegram
}

/// What an inbox item probably wants to become. Produced on-device by the
/// Foundation Models classifier (or left `unknown` when AI is unavailable);
/// always a suggestion, never an automatic conversion.
public enum SuggestedItemKind: String, Codable, CaseIterable, Sendable {
    case note
    case task
    case noteAndTask = "note_and_task"
    case reference
    case unknown
}

public enum HermesContextKind: String, Codable, CaseIterable, Sendable {
    case email
    case calendar
    case summary
}
