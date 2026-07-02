import SwiftUI
import SwiftData
import HermesNotesCore

/// The fastest path into the system: text in, InboxItem out, done. No
/// mandatory metadata, no decisions at capture time.
struct QuickCaptureView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CalmSectionLabel("Capture")

            TextField("What's on your mind?", text: $text, axis: .vertical)
                .lineLimit(3...6)
                .focused($isFocused)
                .onSubmit(save)

            HStack {
                Spacer()
                Button("Save to Inbox", action: save)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(CalmTheme.screenPadding)
        .onAppear { isFocused = true }
    }

    private func save() {
        let content = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        context.insert(InboxItem(source: .localCapture, rawContent: content))
        dismiss()
    }
}
