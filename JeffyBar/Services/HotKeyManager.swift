import Foundation
import HotKey

@MainActor
class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    private var openHotKey: HotKey?
    private var selectAskHotKey: HotKey?
    private var screenshotHotKey: HotKey?
    private init() {}

    func register() {
        openHotKey = HotKey(key: .j, modifiers: [.command])
        openHotKey?.keyDownHandler = {
            Task { @MainActor in
                NotificationCenter.default.post(name: .openJeffWindow, object: nil)
            }
        }

        selectAskHotKey = HotKey(key: .space, modifiers: [.option])
        selectAskHotKey?.keyDownHandler = {
            Task { @MainActor in
                NotificationCenter.default.post(name: .selectAndAsk, object: nil)
            }
        }

        screenshotHotKey = HotKey(key: .j, modifiers: [.command, .shift])
        screenshotHotKey?.keyDownHandler = {
            Task { @MainActor in
                NotificationCenter.default.post(name: .captureScreenshot, object: nil)
            }
        }
    }

    func unregister() {
        openHotKey = nil; selectAskHotKey = nil; screenshotHotKey = nil
    }
}

extension Notification.Name {
    static let openJeffWindow = Notification.Name("com.jeffybar.openJeffWindow")
    static let selectAndAsk = Notification.Name("com.jeffybar.selectAndAsk")
    static let captureScreenshot = Notification.Name("com.jeffybar.captureScreenshot")
}
