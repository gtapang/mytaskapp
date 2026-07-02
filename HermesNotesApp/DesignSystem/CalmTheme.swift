import SwiftUI
import HermesNotesCore

/// The whole visual identity in one small file: one accent, neutral
/// surfaces, generous spacing, quiet typography. If a screen needs more than
/// this, the screen is probably too busy.
enum CalmTheme {
    static let accent = Color(red: 0.29, green: 0.47, blue: 0.42) // muted sage

    static let cardCornerRadius: CGFloat = 14
    static let screenPadding: CGFloat = 16

    static func priorityColor(_ priority: HermesNotesCore.TaskPriority) -> Color {
        switch priority {
        case .none: .secondary
        case .low: .blue.opacity(0.7)
        case .medium: .orange.opacity(0.8)
        case .high: .red.opacity(0.8)
        }
    }
}

/// Standard quiet card used across Today, Calendar, and planning surfaces.
struct CalmCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: CalmTheme.cardCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

extension View {
    func calmCard() -> some View {
        modifier(CalmCard())
    }
}

/// Small section label used instead of loud headers.
struct CalmSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .kerning(0.6)
    }
}

/// A single quiet glyph for reminders — never a banner, never a badge.
struct ReminderGlyph: View {
    let date: Date?

    var body: some View {
        if date != nil {
            Image(systemName: "bell")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Has reminder")
        }
    }
}
