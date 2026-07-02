import Foundation
import EventKit

/// Read-focused EventKit wrapper for the in-app calendar. v1 displays the
/// system calendar accounts directly; event creation stays in the system
/// calendar app.
@MainActor
@Observable
final class CalendarService {
    enum AccessState {
        case undetermined
        case granted
        case denied
    }

    private let store = EKEventStore()
    private(set) var accessState: AccessState = .undetermined

    struct Event: Identifiable, Equatable, Sendable {
        var id: String
        var title: String
        var start: Date
        var end: Date
        var isAllDay: Bool
        var calendarName: String
    }

    func requestAccessIfNeeded() async {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            accessState = .granted
        case .notDetermined:
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            accessState = granted ? .granted : .denied
        default:
            accessState = .denied
        }
    }

    func events(on day: Date, calendar: Calendar = .current) -> [Event] {
        guard accessState == .granted else { return [] }
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .map { ek in
                Event(
                    id: ek.eventIdentifier ?? UUID().uuidString,
                    title: ek.title ?? "Untitled event",
                    start: ek.startDate,
                    end: ek.endDate,
                    isAllDay: ek.isAllDay,
                    calendarName: ek.calendar?.title ?? ""
                )
            }
            .sorted { ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start) }
    }

    /// Days in the given month that have at least one event — used for the
    /// quiet dot markers on the month grid.
    func daysWithEvents(inMonthOf day: Date, calendar: Calendar = .current) -> Set<Int> {
        guard accessState == .granted,
              let interval = calendar.dateInterval(of: .month, for: day)
        else { return [] }
        let predicate = store.predicateForEvents(withStart: interval.start, end: interval.end, calendars: nil)
        return Set(store.events(matching: predicate).map { calendar.component(.day, from: $0.startDate) })
    }
}
