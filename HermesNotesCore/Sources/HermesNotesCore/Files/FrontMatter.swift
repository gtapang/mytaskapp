import Foundation

/// Minimal YAML-subset front matter used by the markdown file mirror.
/// Supports exactly what `NoteFileCodec` writes: scalar strings, bools,
/// ISO-8601 dates, and inline string arrays (`tags: [a, b]`). This is not a
/// general YAML parser and is only guaranteed to round-trip its own output,
/// though it stays tolerant of hand edits to values it understands.
public enum FrontMatter {
    public enum Value: Equatable, Sendable {
        case string(String)
        case bool(Bool)
        case array([String])
    }

    public static func serialize(_ fields: [(String, Value)]) -> String {
        var lines = ["---"]
        for (key, value) in fields {
            switch value {
            case .string(let s):
                lines.append("\(key): \(quoteIfNeeded(s))")
            case .bool(let b):
                lines.append("\(key): \(b)")
            case .array(let items):
                lines.append("\(key): [\(items.map(quoteIfNeeded).joined(separator: ", "))]")
            }
        }
        lines.append("---")
        return lines.joined(separator: "\n")
    }

    /// Splits a document into parsed front matter fields and the remaining
    /// markdown body. Returns nil fields if the document has no front matter.
    public static func parse(document: String) -> (fields: [String: Value]?, body: String) {
        let lines = document.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard lines.first == "---" else { return (nil, document) }
        guard let closeIndex = lines.dropFirst().firstIndex(of: "---") else { return (nil, document) }

        var fields: [String: Value] = [:]
        for line in lines[1..<closeIndex] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[line.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
            let raw = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            fields[key] = parseValue(raw)
        }

        let bodyLines = lines[(closeIndex + 1)...]
        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        return (fields, body)
    }

    private static func parseValue(_ raw: String) -> Value {
        if raw == "true" { return .bool(true) }
        if raw == "false" { return .bool(false) }
        if raw.hasPrefix("["), raw.hasSuffix("]") {
            let inner = raw.dropFirst().dropLast()
            if inner.trimmingCharacters(in: .whitespaces).isEmpty { return .array([]) }
            let items = splitTopLevel(String(inner)).map { unquote($0.trimmingCharacters(in: .whitespaces)) }
            return .array(items)
        }
        return .string(unquote(raw))
    }

    /// Splits on commas while respecting double-quoted segments.
    private static func splitTopLevel(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var inQuotes = false
        var previous: Character?
        for char in text {
            if char == "\"" && previous != "\\" { inQuotes.toggle() }
            if char == "," && !inQuotes {
                items.append(current)
                current = ""
            } else {
                current.append(char)
            }
            previous = char
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty || !items.isEmpty {
            items.append(current)
        }
        return items
    }

    private static func quoteIfNeeded(_ s: String) -> String {
        let needsQuoting = s.isEmpty || s.contains(where: { ":,#[]{}\"\n".contains($0) })
            || s != s.trimmingCharacters(in: .whitespaces)
            || s == "true" || s == "false"
        guard needsQuoting else { return s }
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private static func unquote(_ s: String) -> String {
        guard s.hasPrefix("\""), s.hasSuffix("\""), s.count >= 2 else { return s }
        return String(s.dropFirst().dropLast())
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
