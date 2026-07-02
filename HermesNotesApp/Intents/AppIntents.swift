import AppIntents
import Foundation
import SwiftData

/// App Intents surface: capture, note/task creation, and screen deep links —
/// available to Siri, Spotlight, Shortcuts, and Apple Intelligence.

// MARK: - Capture

struct CaptureToInboxIntent: AppIntent {
    static let title: LocalizedStringResource = "Capture a Thought"
    static let description = IntentDescription("Saves text straight into the Hermes Notes inbox.")

    @Parameter(title: "Text", inputOptions: String.IntentInputOptions(multiline: true))
    var text: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.mainContext
        context.insert(InboxItem(source: .localCapture, rawContent: text))
        try context.save()
        return .result(dialog: "Captured to Inbox.")
    }
}

// MARK: - Create note

struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"
    static let description = IntentDescription("Creates a new markdown note.")

    @Parameter(title: "Title")
    var noteTitle: String

    @Parameter(title: "Body", default: "", inputOptions: String.IntentInputOptions(multiline: true))
    var body: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<NoteEntity> & ProvidesDialog {
        let context = PersistenceController.shared.mainContext
        let note = Note(title: noteTitle, markdownBody: body)
        context.insert(note)
        try context.save()
        return .result(value: NoteEntity(note: note), dialog: "Note created.")
    }
}

// MARK: - Create task

struct CreateTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Task"
    static let description = IntentDescription("Creates a task, optionally due today.")

    @Parameter(title: "Title")
    var taskTitle: String

    @Parameter(title: "Due today", default: false)
    var dueToday: Bool

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = PersistenceController.shared.mainContext
        context.insert(TaskItem(
            title: taskTitle,
            dueDate: dueToday ? Calendar.current.startOfDay(for: .now) : nil
        ))
        try context.save()
        return .result(dialog: "Task created.")
    }
}

// MARK: - Open screen

enum AppScreenIntentValue: String, AppEnum {
    case today, notes, calendar, tasks, eisenhower, inbox

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Screen"
    static let caseDisplayRepresentations: [AppScreenIntentValue: DisplayRepresentation] = [
        .today: "Today",
        .notes: "Notes",
        .calendar: "Calendar",
        .tasks: "Tasks",
        .eisenhower: "Eisenhower",
        .inbox: "Inbox",
    ]
}

struct OpenScreenIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Screen"
    static let description = IntentDescription("Opens one of the six primary screens.")
    static let openAppWhenRun = true

    @Parameter(title: "Screen", default: .today)
    var screen: AppScreenIntentValue

    @MainActor
    func perform() async throws -> some IntentResult {
        AppIntentRouter.shared.pendingScreen = AppScreen(rawValue: screen.rawValue) ?? .today
        return .result()
    }
}

/// Tiny bridge from intent process-space to the live UI: the root view
/// observes this and applies the pending screen.
@MainActor
@Observable
final class AppIntentRouter {
    static let shared = AppIntentRouter()
    var pendingScreen: AppScreen?
}

// MARK: - Note entity (Spotlight / Apple Intelligence)

struct NoteEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    static let defaultQuery = NoteEntityQuery()

    var id: UUID
    var title: String
    var preview: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(preview)"
        )
    }

    @MainActor
    init(note: Note) {
        self.id = note.id
        self.title = note.displayTitle
        self.preview = note.previewText
    }
}

struct NoteEntityQuery: EntityQuery, EntityStringQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [NoteEntity] {
        let context = PersistenceController.shared.mainContext
        return try context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate { identifiers.contains($0.id) })
        ).map(NoteEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [NoteEntity] {
        let context = PersistenceController.shared.mainContext
        return try context.fetch(
            FetchDescriptor<Note>(predicate: #Predicate {
                $0.title.localizedStandardContains(string) && !$0.isArchived
            })
        ).map(NoteEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [NoteEntity] {
        let context = PersistenceController.shared.mainContext
        var descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        return try context.fetch(descriptor).map(NoteEntity.init)
    }
}

// MARK: - Shortcuts

struct HermesNotesShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CaptureToInboxIntent(),
            phrases: [
                "Capture a thought in \(.applicationName)",
                "Add to my \(.applicationName) inbox",
            ],
            shortTitle: "Capture",
            systemImageName: "tray.and.arrow.down"
        )
        AppShortcut(
            intent: OpenScreenIntent(),
            phrases: [
                "Start my day in \(.applicationName)",
                "Open \(.applicationName)",
            ],
            shortTitle: "Start my day",
            systemImageName: "sun.max"
        )
        AppShortcut(
            intent: CreateTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
            ],
            shortTitle: "New task",
            systemImageName: "checkmark.circle"
        )
    }
}
