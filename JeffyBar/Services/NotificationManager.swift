import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func setupCategories() {
        let replyAction = UNNotificationAction(identifier: "reply", title: "Reply", options: [])
        let dismissAction = UNNotificationAction(identifier: "dismiss", title: "Dismiss", options: [.destructive])

        let category = UNNotificationCategory(
            identifier: "JEFF_RESPONSE",
            actions: [replyAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    func notifyResponseReady(preview: String) {
        let content = UNMutableNotificationContent()
        content.title = "Jeff replied"
        content.body = preview.count > 100 ? String(preview.prefix(100)) + "..." : preview
        content.sound = .default
        content.categoryIdentifier = "JEFF_RESPONSE"

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// Handle notification actions
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "reply":
            // Open Jeff and focus input
            NotificationCenter.default.post(name: .openJeffWindow, object: nil)
        case "dismiss":
            // Just close the notification
            break
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification body — open Jeff
            NotificationCenter.default.post(name: .openJeffWindow, object: nil)
        default:
            break
        }

        completionHandler()
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
