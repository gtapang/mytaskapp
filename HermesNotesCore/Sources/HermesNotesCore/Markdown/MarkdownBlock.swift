import Foundation

/// Block-level markdown model for v1. Deliberately simple: enough structure
/// for a calm, readable preview and for task extraction, with no wiki-links,
/// tables, or nesting beyond one list level.
public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case bulletItem(text: String)
    case orderedItem(number: Int, text: String)
    case taskItem(done: Bool, text: String)
    case quote(text: String)
    case codeBlock(language: String?, code: String)
    case horizontalRule
}

public enum MarkdownParser {
    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraphBuffer: [String] = []
        var codeBuffer: [String] = []
        var codeLanguage: String?
        var inCode = false

        func flushParagraph() {
            if !paragraphBuffer.isEmpty {
                blocks.append(.paragraph(text: paragraphBuffer.joined(separator: " ")))
                paragraphBuffer.removeAll()
            }
        }

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if inCode {
                if trimmed.hasPrefix("```") {
                    blocks.append(.codeBlock(language: codeLanguage, code: codeBuffer.joined(separator: "\n")))
                    codeBuffer.removeAll()
                    codeLanguage = nil
                    inCode = false
                } else {
                    codeBuffer.append(line)
                }
                continue
            }

            if trimmed.hasPrefix("```") {
                flushParagraph()
                let lang = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                codeLanguage = lang.isEmpty ? nil : lang
                inCode = true
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(.horizontalRule)
                continue
            }

            if trimmed.hasPrefix("#") {
                let level = trimmed.prefix(while: { $0 == "#" }).count
                if level <= 6 {
                    let text = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty {
                        flushParagraph()
                        blocks.append(.heading(level: level, text: text))
                        continue
                    }
                }
            }

            if let task = parseTaskItem(trimmed) {
                flushParagraph()
                blocks.append(task)
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                blocks.append(.bulletItem(text: String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)))
                continue
            }

            if let ordered = parseOrderedItem(trimmed) {
                flushParagraph()
                blocks.append(ordered)
                continue
            }

            if trimmed.hasPrefix(">") {
                flushParagraph()
                blocks.append(.quote(text: trimmed.dropFirst().trimmingCharacters(in: .whitespaces)))
                continue
            }

            paragraphBuffer.append(trimmed)
        }

        if inCode {
            // Unterminated fence: keep the content rather than losing it.
            blocks.append(.codeBlock(language: codeLanguage, code: codeBuffer.joined(separator: "\n")))
        }
        flushParagraph()
        return blocks
    }

    /// One-line plain-text preview for list rows: first non-heading text with
    /// inline markers stripped.
    public static func plainTextPreview(_ markdown: String, maxLength: Int = 140) -> String {
        for block in parse(markdown) {
            let text: String
            switch block {
            case .paragraph(let t), .bulletItem(let t), .quote(let t):
                text = t
            case .taskItem(_, let t), .heading(_, let t):
                text = t
            case .orderedItem(_, let t):
                text = t
            case .codeBlock, .horizontalRule:
                continue
            }
            let stripped = strippingInlineMarkers(text)
            if !stripped.isEmpty { return String(stripped.prefix(maxLength)) }
        }
        return ""
    }

    /// Removes `**`, `*`, `_`, and backtick markers for plain-text contexts.
    public static func strippingInlineMarkers(_ text: String) -> String {
        var out = text
        for marker in ["**", "__", "*", "_", "`"] {
            out = out.replacingOccurrences(of: marker, with: "")
        }
        return out.trimmingCharacters(in: .whitespaces)
    }

    private static func parseTaskItem(_ line: String) -> MarkdownBlock? {
        for (prefix, done) in [("- [ ] ", false), ("- [x] ", true), ("- [X] ", true)] {
            if line.hasPrefix(prefix) {
                return .taskItem(done: done, text: String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces))
            }
        }
        return nil
    }

    private static func parseOrderedItem(_ line: String) -> MarkdownBlock? {
        guard let dotIndex = line.firstIndex(of: "."), dotIndex != line.startIndex else { return nil }
        let head = line[line.startIndex..<dotIndex]
        guard head.allSatisfy(\.isNumber), let number = Int(head) else { return nil }
        let rest = line[line.index(after: dotIndex)...]
        guard rest.first == " " else { return nil }
        return .orderedItem(number: number, text: rest.trimmingCharacters(in: .whitespaces))
    }
}
