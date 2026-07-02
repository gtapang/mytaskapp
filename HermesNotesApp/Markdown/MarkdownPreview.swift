import SwiftUI
import HermesNotesCore

/// Read view for a note: the core block parser rendered as calm SwiftUI
/// text. Inline styling (bold/italic/code) goes through
/// `AttributedString(markdown:)`, block structure through `MarkdownParser`,
/// so reading stays pleasant without a heavyweight rendering dependency.
struct MarkdownPreview: View {
    let markdown: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(MarkdownParser.parse(markdown).enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .padding(CalmTheme.screenPadding)
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inlineText(text)
                .font(headingFont(level))
                .padding(.top, level <= 2 ? 8 : 4)
        case .paragraph(let text):
            inlineText(text)
                .font(.body)
                .lineSpacing(3)
        case .bulletItem(let text):
            listRow(marker: "•", text: text)
        case .orderedItem(let number, let text):
            listRow(marker: "\(number).", text: text)
        case .taskItem(let done, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(done ? CalmTheme.accent : .secondary)
                inlineText(text)
                    .strikethrough(done, color: .secondary)
                    .foregroundStyle(done ? .secondary : .primary)
            }
        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(CalmTheme.accent.opacity(0.5))
                    .frame(width: 3)
                inlineText(text)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        case .codeBlock(_, let code):
            Text(code)
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
        case .horizontalRule:
            Divider().padding(.vertical, 4)
        }
    }

    private func listRow(marker: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(marker)
                .font(.body)
                .foregroundStyle(.secondary)
            inlineText(text)
                .font(.body)
        }
    }

    /// Inline markdown (bold, italic, code, links) via Foundation's parser;
    /// falls back to plain text for anything it can't parse.
    private func inlineText(_ text: String) -> Text {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            return Text(attributed)
        }
        return Text(text)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2.weight(.semibold)
        case 2: .title3.weight(.semibold)
        case 3: .headline
        default: .subheadline.weight(.semibold)
        }
    }
}
