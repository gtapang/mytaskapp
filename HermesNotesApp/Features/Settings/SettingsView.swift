import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Minimal settings: the Hermes connection and the mirror folder. Everything
/// else is convention.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var baseURL = ""
    @State private var token = ""
    @State private var isFolderPickerPresented = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Base URL", text: $baseURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Bearer token", text: $token)
                } header: {
                    Text("Hermes")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if app.hermes.isConfigured {
                            if let lastSync = app.hermes.lastSyncAt {
                                Text("Last sync \(lastSync.formatted(.relative(presentation: .named))).")
                            }
                            if app.hermes.pendingOutboxCount > 0 {
                                Text("\(app.hermes.pendingOutboxCount) action(s) queued for delivery.")
                            }
                            if let error = app.hermes.lastError {
                                Text("Last error: \(error)")
                            }
                        } else {
                            Text("Hermes powers email/calendar importance, Telegram capture, and wiki routing. The app works fully offline without it.")
                        }
                    }
                }

                Section {
                    LabeledContent("Mirror folder") {
                        Text(PreferredDirectory.current.lastPathComponent)
                            .lineLimit(1)
                    }
                    #if !targetEnvironment(macCatalyst) && !os(macOS)
                    Button(PreferredDirectory.hasExplicitChoice ? "Change folder…" : "Choose folder…") {
                        isFolderPickerPresented = true
                    }
                    if PreferredDirectory.hasExplicitChoice {
                        Button("Use app storage", role: .destructive) {
                            PreferredDirectory.clearPreferred()
                        }
                    }
                    #endif
                } header: {
                    Text("Markdown mirror")
                } footer: {
                    Text("Notes are mirrored as markdown files with front matter — the local-first, wiki-aligned copy of your data (aim it at the folder that syncs to ~/Desktop/M).")
                }

                Section("On-device intelligence") {
                    LabeledContent("Apple Intelligence") {
                        Text(app.intelligence.isAvailable ? "Available" : "Unavailable")
                            .foregroundStyle(app.intelligence.isAvailable ? CalmTheme.accent : .secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        app.hermes.baseURLString = baseURL.trimmingCharacters(in: .whitespaces)
                        app.hermes.bearerToken = token.trimmingCharacters(in: .whitespaces)
                        Task { await app.hermes.syncNow(context: context) }
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isFolderPickerPresented,
                allowedContentTypes: [.folder]
            ) { result in
                if case .success(let url) = result {
                    PreferredDirectory.setPreferred(url: url)
                }
            }
            .onAppear {
                baseURL = app.hermes.baseURLString
                token = app.hermes.bearerToken
            }
        }
    }
}
