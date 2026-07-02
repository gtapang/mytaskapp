import Foundation

/// Write-through markdown mirror of notes under the preferred directory
/// (`~/Desktop/M/HermesNotes` on Mac-class systems; a bookmarked folder or the
/// app's Documents directory on iOS — the app layer resolves the root).
///
/// Layout: `<root>/Notes/<notebook|folder|"Unfiled">/<slug>-<id8>.md`
/// Archived notes move to `<root>/Archive/`.
///
/// SwiftData remains the operational source of truth; this mirror is the
/// durable, human-readable, Hermes-wiki-aligned representation.
public struct MarkdownFileStore: Sendable {
    public let rootURL: URL
    private let fileManager: FileManager = .default

    public init(rootURL: URL) {
        self.rootURL = rootURL
    }

    /// Writes (or rewrites) a note's mirror file, moving it if its grouping
    /// or archived state changed. Returns the file URL written.
    @discardableResult
    public func write(_ note: NoteSnapshot) throws -> URL {
        let destination = url(for: note)
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        // Remove any previous file for this note that lives elsewhere
        // (renamed title, moved notebook, archived).
        if let existing = try? existingFileURL(for: note.id), existing != destination {
            try? fileManager.removeItem(at: existing)
        }
        let text = NoteFileCodec.encode(note)
        try text.data(using: .utf8)!.write(to: destination, options: .atomic)
        return destination
    }

    public func delete(noteID: UUID) throws {
        if let existing = try existingFileURL(for: noteID) {
            try fileManager.removeItem(at: existing)
        }
    }

    /// Reads every note mirror file under the root. Files that fail to decode
    /// are skipped (the mirror is tolerant of stray files in the directory).
    public func readAll() throws -> [NoteSnapshot] {
        guard fileManager.fileExists(atPath: rootURL.path) else { return [] }
        return try markdownFiles(under: rootURL).compactMap { url in
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return NoteFileCodec.decode(text)
        }
    }

    public func url(for note: NoteSnapshot) -> URL {
        let group = note.isArchived
            ? "Archive"
            : "Notes/\(sanitizedGroup(note.notebook ?? note.folder))"
        let name = "\(Slug.make(note.title))-\(Slug.shortID(note.id)).md"
        return rootURL.appendingPathComponent(group).appendingPathComponent(name)
    }

    private func sanitizedGroup(_ group: String?) -> String {
        guard let group, !group.isEmpty else { return "Unfiled" }
        return group
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
    }

    private func existingFileURL(for id: UUID) throws -> URL? {
        guard fileManager.fileExists(atPath: rootURL.path) else { return nil }
        let suffix = "-\(Slug.shortID(id)).md"
        return try markdownFiles(under: rootURL).first { $0.lastPathComponent.hasSuffix(suffix) }
    }

    private func markdownFiles(under root: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "md" }
    }
}
