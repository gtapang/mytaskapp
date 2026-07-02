import Foundation
import HermesNotesCore

/// Bridges SwiftData note saves to the markdown file mirror. Views call
/// `mirror(_:)` after meaningful edits; writes happen off the main actor and
/// failures never interrupt editing (the mirror is derived state and heals on
/// the next save).
@Observable
final class NoteMirrorService {
    private(set) var lastError: String?

    var store: MarkdownFileStore {
        MarkdownFileStore(rootURL: PreferredDirectory.current)
    }

    func mirror(_ snapshot: NoteSnapshot) {
        let store = self.store
        Task.detached(priority: .utility) { [weak self] in
            do {
                try store.write(snapshot)
                await MainActor.run { self?.lastError = nil }
            } catch {
                await MainActor.run { self?.lastError = error.localizedDescription }
            }
        }
    }

    func remove(noteID: UUID) {
        let store = self.store
        Task.detached(priority: .utility) {
            try? store.delete(noteID: noteID)
        }
    }
}
