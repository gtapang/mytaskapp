import Foundation
import SwiftData

/// Owns the SwiftData container. SwiftData is the operational source of
/// truth; the markdown mirror under the preferred directory is derived from
/// it (see `NoteMirrorService`).
@MainActor
enum PersistenceController {
    static let schema = Schema([
        Note.self,
        TaskItem.self,
        Tag.self,
        Folder.self,
        Notebook.self,
        Project.self,
        InboxItem.self,
        HermesContextItem.self,
    ])

    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    /// In-memory container for previews and UI tests.
    static func preview() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: config)
    }
}
