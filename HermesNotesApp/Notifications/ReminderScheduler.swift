import Foundation
import UserNotifications

/// Optional per-note/per-task local reminders. Purposeful and minimal:
/// one notification per item, silently replaced on reschedule, removed on
/// completion or clearing.
@MainActor
@Observable
final class ReminderScheduler {
    private let center = UNUserNotificationCenter.current()
    private(set) var isAuthorized = false

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        default:
            isAuthorized = false
        }
    }

    func scheduleNoteReminder(noteID: UUID, title: String, at date: Date) async {
        await schedule(identifier: "note-\(noteID.uuidString)", title: title, body: "Note reminder", at: date)
    }

    func scheduleTaskReminder(taskID: UUID, title: String, at date: Date) async {
        await schedule(identifier: "task-\(taskID.uuidString)", title: title, body: "Task reminder", at: date)
    }

    func cancelNoteReminder(noteID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["note-\(noteID.uuidString)"])
    }

    func cancelTaskReminder(taskID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["task-\(taskID.uuidString)"])
    }

    private func schedule(identifier: String, title: String, body: String, at date: Date) async {
        await requestAuthorizationIfNeeded()
        guard isAuthorized, date > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
