import SwiftUI

/// The six primary surfaces as a flat tab bar — no nesting, no dashboard.
struct RootView: View {
    @Environment(AppEnvironment.self) private var app
    // Computed so access stays inside MainActor-isolated body.
    private var intentRouter: AppIntentRouter { .shared }

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedScreen) {
            Tab(AppScreen.today.title, systemImage: AppScreen.today.systemImage, value: .today) {
                TodayView()
            }
            Tab(AppScreen.notes.title, systemImage: AppScreen.notes.systemImage, value: .notes) {
                NotesListView()
            }
            Tab(AppScreen.calendar.title, systemImage: AppScreen.calendar.systemImage, value: .calendar) {
                CalendarView()
            }
            Tab(AppScreen.tasks.title, systemImage: AppScreen.tasks.systemImage, value: .tasks) {
                TasksView()
            }
            Tab(AppScreen.eisenhower.title, systemImage: AppScreen.eisenhower.systemImage, value: .eisenhower) {
                EisenhowerView()
            }
            Tab(AppScreen.inbox.title, systemImage: AppScreen.inbox.systemImage, value: .inbox) {
                InboxView()
            }
        }
        .sheet(isPresented: $app.isQuickCapturePresented) {
            QuickCaptureView()
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: intentRouter.pendingScreen) { _, screen in
            // Deep links from OpenScreenIntent (Siri / Shortcuts / Spotlight).
            if let screen {
                app.selectedScreen = screen
                intentRouter.pendingScreen = nil
            }
        }
    }
}
