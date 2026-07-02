import SwiftUI
import SwiftData

@main
struct HermesNotesApp: App {
    @State private var environment = AppEnvironment()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .tint(CalmTheme.accent)
        }
        .modelContainer(PersistenceController.shared)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // Opportunistic Hermes sync on foreground: pulls important
                // context and Telegram captures, drains the offline outbox.
                let context = PersistenceController.shared.mainContext
                Task { await environment.hermes.syncNow(context: context) }
            }
        }
    }
}
