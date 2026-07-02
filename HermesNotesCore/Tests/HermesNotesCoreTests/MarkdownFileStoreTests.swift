import Foundation
import Testing
@testable import HermesNotesCore

@Suite struct MarkdownFileStoreTests {
    private func makeStore() throws -> MarkdownFileStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermesnotes-tests-\(UUID().uuidString)")
        return MarkdownFileStore(rootURL: root)
    }

    private func makeNote(title: String = "Test note", notebook: String? = nil, archived: Bool = false) -> NoteSnapshot {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        return NoteSnapshot(
            title: title,
            markdown: "Hello.",
            createdAt: now,
            updatedAt: now,
            notebook: notebook,
            isArchived: archived
        )
    }

    @Test func writesUnderNotebookGroupAndReadsBack() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.rootURL) }

        let note = makeNote(title: "Café plans!", notebook: "Personal")
        let url = try store.write(note)
        #expect(url.path.contains("Notes/Personal/"))
        #expect(url.lastPathComponent.hasPrefix("caf-plans-") || url.lastPathComponent.hasPrefix("cafe-plans-"))
        #expect(try store.readAll() == [note])
    }

    @Test func rewriteMovesFileWhenNotebookOrArchiveChanges() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.rootURL) }

        var note = makeNote(notebook: "Personal")
        try store.write(note)

        note.notebook = "Work"
        let moved = try store.write(note)
        #expect(moved.path.contains("Notes/Work/"))
        #expect(try store.readAll().count == 1)

        note.isArchived = true
        let archived = try store.write(note)
        #expect(archived.path.contains("Archive/"))
        #expect(try store.readAll().count == 1)
    }

    @Test func deleteRemovesMirrorFile() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.rootURL) }

        let note = makeNote()
        try store.write(note)
        try store.delete(noteID: note.id)
        #expect(try store.readAll().isEmpty)
    }

    @Test func readAllSkipsForeignMarkdownFiles() throws {
        let store = try makeStore()
        defer { try? FileManager.default.removeItem(at: store.rootURL) }

        try store.write(makeNote())
        let stray = store.rootURL.appendingPathComponent("Notes/stray.md")
        try "no front matter here".data(using: .utf8)!.write(to: stray)
        #expect(try store.readAll().count == 1)
    }
}
