import Foundation

/// Resolves the root of the markdown mirror, honoring the preferred
/// `~/Desktop/M` location wherever the platform allows it.
///
/// - Mac Catalyst / macOS: `~/Desktop/M/HermesNotes` directly.
/// - iOS: a user-chosen folder (e.g. a synced folder that maps to
///   `~/Desktop/M` on the Mac), persisted as a security-scoped bookmark.
///   Until one is chosen, the app's Documents directory is used so the
///   mirror always exists.
enum PreferredDirectory {
    private static let bookmarkKey = "preferredDirectoryBookmark"

    static var current: URL {
        #if targetEnvironment(macCatalyst) || os(macOS)
        return FileManager.default
            .homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/M/HermesNotes")
        #else
        if let bookmarked = resolveBookmark() {
            return bookmarked
        }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("M")
        #endif
    }

    /// Whether the user has explicitly chosen a mirror folder (iOS only).
    static var hasExplicitChoice: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    /// Stores a user-picked folder (from `fileImporter`) as a bookmark.
    static func setPreferred(url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        if let bookmark = try? url.bookmarkData(options: .minimalBookmark) {
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        }
    }

    static func clearPreferred() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    private static func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale, let refreshed = try? url.bookmarkData(options: .minimalBookmark) {
            UserDefaults.standard.set(refreshed, forKey: bookmarkKey)
        }
        _ = url.startAccessingSecurityScopedResource()
        return url
    }
}
