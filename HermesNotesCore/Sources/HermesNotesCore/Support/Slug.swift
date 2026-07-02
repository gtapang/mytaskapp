import Foundation

public enum Slug {
    /// Filesystem-safe slug for markdown file names: lowercased, alphanumerics
    /// kept, everything else collapsed to single hyphens, capped in length so
    /// paths stay readable.
    public static func make(_ text: String, maxLength: Int = 60) -> String {
        var out = ""
        var lastWasHyphen = true // suppress leading hyphen
        for scalar in text.lowercased().unicodeScalars {
            if ("a"..."z").contains(String(scalar)) || ("0"..."9").contains(String(scalar)) {
                out.append(Character(scalar))
                lastWasHyphen = false
            } else if !lastWasHyphen {
                out.append("-")
                lastWasHyphen = true
            }
            if out.count >= maxLength { break }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "untitled" : out
    }

    /// Short stable suffix from a UUID so slugs never collide.
    public static func shortID(_ id: UUID) -> String {
        String(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).lowercased()
    }
}
