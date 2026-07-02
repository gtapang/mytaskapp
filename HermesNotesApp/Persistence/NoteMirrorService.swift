import Foundation
import HermesNotesCore

/// Bridges SwiftData note saves to the markdown file mirror. Views call
/// `mirror(_:)` after meaningful edits; the file I/O runs in nonisolated
/// helpers so only Sendable values (snapshot + store) leave the main actor,
/// and failures never interrupt editing — the mirror is derived state and
/// heals on the next save.
@MainActor
@Observable
final class NoteMirrorService {
    private(set) var lastError: String?

    var store: MarkdownFileStore {
        MarkdownFileStore(rootURL: PreferredDirectory.current)
    }

    func mirror(_ snapshot: NoteSnapshot) {
        let store = self.store
        Task { [weak self] in
            do {
                try await Self.write(snapshot, using: store)
                self?.lastError = nil
            } catch {
                self?.lastError = error.localizedDescription
            }
        }
    }

    func remove(noteID: UUID) {
        let store = self.store
        Task {
            try? await Self.delete(noteID, using: store)
        }
    }

    private nonisolated static func write(_ snapshot: NoteSnapshot, using store: MarkdownFileStore) async throws {
        try store.write(snapshot)
    }

    private nonisolated static func delete(_ noteID: UUID, using store: MarkdownFileStore) async throws {
        try store.delete(noteID: noteID)
    }
}
