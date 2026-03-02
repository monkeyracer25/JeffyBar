import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            // Silently handle result
        }
    }

    func notifyResponseReady(preview: String) {
        let content = UNMutableNotificationContent()
        content.title = "Jeff replied"
        content.body = preview.count > 100 ? String(preview.prefix(100)) + "..." : preview
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil  // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
