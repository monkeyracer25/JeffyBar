import Foundation
import HotKey

@MainActor
class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    private var hotKey: HotKey?

    private init() {}

    func register() {
        // ⌘+J to open Jeff main window
        hotKey = HotKey(key: .j, modifiers: [.command])
        hotKey?.keyDownHandler = {
            Task { @MainActor in
                HotKeyManager.shared.activateJeff()
            }
        }
    }

    func unregister() {
        hotKey = nil
    }

    private func activateJeff() {
        // Post notification to open main window
        NotificationCenter.default.post(name: .openJeffWindow, object: nil)
    }
}

extension Notification.Name {
    static let openJeffWindow = Notification.Name("com.jeffybar.openJeffWindow")
}
