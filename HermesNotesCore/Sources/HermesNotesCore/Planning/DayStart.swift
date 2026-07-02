import Foundation

/// Inputs for the Today screen's day-start synthesis: a compact, typed digest
/// of what the day holds. The app layer feeds this either to the on-device
/// Foundation Models session (as a prompt) or to `DayStart.fallbackSummary`
/// when Apple Intelligence is unavailable. Pure logic, fully testable.
public struct DayStartDigest: Equatable, Sendable {
    public struct TaskLine: Equatable, Sendable {
        public var title: String
        public var priority: TaskPriority
        public var quadrant: EisenhowerQuadrant
        public var isOverdue: Bool

        public init(title: String, priority: TaskPriority, quadrant: EisenhowerQuadrant, isOverdue: Bool) {
            self.title = title
            self.priority = priority
            self.quadrant = quadrant
            self.isOverdue = isOverdue
        }
    }

    public struct EventLine: Equatable, Sendable {
        public var title: String
        public var start: Date
        public var isAllDay: Bool

        public init(title: String, start: Date, isAllDay: Bool) {
            self.title = title
            self.start = start
            self.isAllDay = isAllDay
        }
    }

    public var date: Date
    public var dueTasks: [TaskLine]
    public var events: [EventLine]
    public var hermesHighlights: [HermesContextPayload]
    public var inboxCount: Int

    public init(
        date: Date,
        dueTasks: [TaskLine],
        events: [EventLine],
        hermesHighlights: [HermesContextPayload],
        inboxCount: Int
    ) {
        self.date = date
        self.dueTasks = dueTasks
        self.events = events
        self.hermesHighlights = hermesHighlights
        self.inboxCount = inboxCount
    }
}

public enum DayStart {
    /// Prompt handed to the on-device model. Kept short and factual — the
    /// model's job is a two-sentence calm briefing, not analysis.
    public static func prompt(for digest: DayStartDigest, calendar: Calendar = .current) -> String {
        var lines: [String] = ["Write a calm two-sentence morning briefing from these facts:"]
        if digest.dueTasks.isEmpty {
            lines.append("- No tasks due today.")
        } else {
            let overdue = digest.dueTasks.filter(\.isOverdue).count
            lines.append("- \(digest.dueTasks.count) task(s) due today\(overdue > 0 ? ", \(overdue) overdue" : "").")
            for task in digest.dueTasks.prefix(5) {
                lines.append("  - \(task.title) [\(task.priority.rawValue)]")
            }
        }
        for event in digest.events.prefix(5) {
            let time = event.isAllDay ? "all day" : Self.timeString(event.start, calendar: calendar)
            lines.append("- Event: \(event.title) (\(time))")
        }
        for item in digest.hermesHighlights.prefix(3) {
            lines.append("- Important \(item.kind.rawValue): \(item.title)")
        }
        if digest.inboxCount > 0 {
            lines.append("- \(digest.inboxCount) unprocessed inbox item(s).")
        }
        return lines.joined(separator: "\n")
    }

    /// Deterministic rule-based briefing used when the on-device model is
    /// unavailable. Same calm register, no intelligence required.
    public static func fallbackSummary(for digest: DayStartDigest, calendar: Calendar = .current) -> String {
        var parts: [String] = []

        switch (digest.dueTasks.count, digest.events.count) {
        case (0, 0):
            parts.append("A clear day — nothing due and no events scheduled.")
        case (let tasks, 0):
            parts.append("\(tasks) task\(tasks == 1 ? "" : "s") due today, with no events on the calendar.")
        case (0, let events):
            parts.append("No tasks due today; \(events) event\(events == 1 ? "" : "s") on the calendar.")
        case (let tasks, let events):
            parts.append("\(tasks) task\(tasks == 1 ? "" : "s") due and \(events) event\(events == 1 ? "" : "s") today.")
        }

        if let firstEvent = digest.events.filter({ !$0.isAllDay }).min(by: { $0.start < $1.start }) {
            parts.append("First up: \(firstEvent.title) at \(timeString(firstEvent.start, calendar: calendar)).")
        } else if let topTask = digest.dueTasks.max(by: { $0.priority < $1.priority }) {
            parts.append("Top task: \(topTask.title).")
        }

        if !digest.hermesHighlights.isEmpty {
            parts.append("\(digest.hermesHighlights.count) important item\(digest.hermesHighlights.count == 1 ? "" : "s") surfaced by Hermes.")
        }

        return parts.joined(separator: " ")
    }

    private static func timeString(_ date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return String(format: "%d:%02d", hour, minute)
    }
}
