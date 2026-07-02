import Foundation
import SwiftUI
import HermesNotesCore

/// Composition root: one place that owns the app's long-lived services.
/// Injected into the SwiftUI environment at launch.
@MainActor
@Observable
final class AppEnvironment {
    let intelligence: any NoteIntelligence
    let hermes: HermesSyncService
    let mirror: NoteMirrorService
    let calendar: CalendarService
    let reminders: ReminderScheduler

    /// Tab selection, also driven by App Intents deep links.
    var selectedScreen: AppScreen = .today
    var isQuickCapturePresented = false

    init(
        intelligence: (any NoteIntelligence)? = nil,
        hermes: HermesSyncService? = nil
    ) {
        self.intelligence = intelligence ?? IntelligenceFactory.make()
        self.hermes = hermes ?? HermesSyncService()
        self.mirror = NoteMirrorService()
        self.calendar = CalendarService()
        self.reminders = ReminderScheduler()
    }
}

/// The six primary surfaces. Raw values are stable identifiers used by the
/// `OpenScreenIntent` App Intent.
enum AppScreen: String, CaseIterable, Identifiable {
    case today
    case notes
    case calendar
    case tasks
    case eisenhower
    case inbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .notes: "Notes"
        case .calendar: "Calendar"
        case .tasks: "Tasks"
        case .eisenhower: "Eisenhower"
        case .inbox: "Inbox"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.max"
        case .notes: "note.text"
        case .calendar: "calendar"
        case .tasks: "checkmark.circle"
        case .eisenhower: "square.grid.2x2"
        case .inbox: "tray"
        }
    }
}
