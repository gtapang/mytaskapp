import Foundation
import Testing
@testable import HermesNotesCore

@Suite struct DayStartTests {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func makeDigest(tasks: Int = 0, events: Int = 0, hermes: Int = 0, inbox: Int = 0) -> DayStartDigest {
        let day = Date(timeIntervalSince1970: 1_750_000_000)
        return DayStartDigest(
            date: day,
            dueTasks: (0..<tasks).map {
                .init(title: "Task \($0)", priority: $0 == 0 ? .high : .medium, quadrant: .doFirst, isOverdue: false)
            },
            events: (0..<events).map {
                .init(title: "Event \($0)", start: day.addingTimeInterval(Double(3600 * ($0 + 9))), isAllDay: false)
            },
            hermesHighlights: (0..<hermes).map {
                HermesContextPayload(id: "h\($0)", kind: .email, title: "Email \($0)", summary: "…", importance: 0.9)
            },
            inboxCount: inbox
        )
    }

    @Test func fallbackHandlesClearDay() {
        let summary = DayStart.fallbackSummary(for: makeDigest(), calendar: utc)
        #expect(summary == "A clear day — nothing due and no events scheduled.")
    }

    @Test func fallbackLeadsWithFirstEventThenMentionsHermes() {
        let summary = DayStart.fallbackSummary(for: makeDigest(tasks: 2, events: 1, hermes: 2), calendar: utc)
        #expect(summary.contains("2 tasks due and 1 event today."))
        #expect(summary.contains("First up: Event 0"))
        #expect(summary.contains("2 important items surfaced by Hermes."))
    }

    @Test func fallbackFallsBackToTopTaskWhenNoTimedEvents() {
        let summary = DayStart.fallbackSummary(for: makeDigest(tasks: 3), calendar: utc)
        #expect(summary.contains("Top task: Task 0."))
    }

    @Test func promptStaysCompactAndFactual() {
        let prompt = DayStart.prompt(for: makeDigest(tasks: 8, events: 7, hermes: 5, inbox: 3), calendar: utc)
        #expect(prompt.contains("8 task(s) due today"))
        // Caps keep the prompt calm and cheap: 5 tasks, 5 events, 3 highlights.
        #expect(prompt.components(separatedBy: "  - ").count - 1 == 5)
        #expect(prompt.components(separatedBy: "- Event:").count - 1 == 5)
        #expect(prompt.components(separatedBy: "- Important").count - 1 == 3)
        #expect(prompt.contains("3 unprocessed inbox item(s)."))
    }
}

@Suite struct CoreTypeTests {
    @Test func quadrantFromFlags() {
        #expect(EisenhowerQuadrant(urgent: true, important: true) == .doFirst)
        #expect(EisenhowerQuadrant(urgent: false, important: true) == .schedule)
        #expect(EisenhowerQuadrant(urgent: true, important: false) == .delegate)
        #expect(EisenhowerQuadrant(urgent: false, important: false) == .eliminate)
    }

    @Test func priorityOrdering() {
        #expect(TaskPriority.none < .low)
        #expect(TaskPriority.low < .medium)
        #expect(TaskPriority.medium < .high)
        #expect([TaskPriority.high, .none, .medium].max() == .high)
    }

    @Test func slugsAreFilesystemSafe() {
        #expect(Slug.make("Meeting: Q3 / planning!") == "meeting-q3-planning")
        #expect(Slug.make("   ") == "untitled")
        #expect(Slug.make(String(repeating: "a", count: 100)).count <= 60)
    }
}
