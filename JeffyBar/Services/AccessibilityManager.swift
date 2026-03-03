import ApplicationServices
import AppKit

@MainActor
class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    @Published var hasPermission: Bool = false

    private init() { updatePermissionStatus() }

    func updatePermissionStatus() {
        hasPermission = AXIsProcessTrusted()
    }

    func requestPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        hasPermission = AXIsProcessTrustedWithOptions(opts)
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
