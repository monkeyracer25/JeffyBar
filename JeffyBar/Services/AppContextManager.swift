import AppKit
import ApplicationServices

struct AppContext {
    let appName: String
    let bundleId: String?
    let windowTitle: String?
    let browserURL: String?
    let service: KnownService?
    let timestamp: Date

    func asSystemContext() -> String {
        var parts = ["[App: \(appName)]"]
        if let t = windowTitle { parts.append("[Window: \(t)]") }
        if let u = browserURL { parts.append("[URL: \(u)]") }
        if let s = service { parts.append("[Service: \(s.displayName)]") }
        return parts.joined(separator: " ")
    }
}

@MainActor
class AppContextManager: ObservableObject {
    static let shared = AppContextManager()
    @Published var currentContext: AppContext?

    private static let browserBundleIds: Set<String> = [
        "com.google.Chrome", "com.apple.Safari",
        "company.thebrowser.Browser", // Arc
        "org.mozilla.firefox",
        "com.microsoft.edgemac", "com.brave.Browser",
    ]

    private init() {}

    func captureCurrentContext() -> AppContext {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "Unknown"
        let bundleId = app?.bundleIdentifier

        // Window title via AXUIElement
        let windowTitle = getWindowTitle(pid: app?.processIdentifier)

        // Browser URL if applicable
        var browserURL: String? = nil
        if let bid = bundleId, Self.browserBundleIds.contains(bid) {
            browserURL = getBrowserURL(appName: appName, bundleId: bid)
        }

        let service = browserURL.flatMap { KnownService.detect(from: $0) }

        let ctx = AppContext(
            appName: appName, bundleId: bundleId,
            windowTitle: windowTitle, browserURL: browserURL,
            service: service, timestamp: Date()
        )
        currentContext = ctx
        return ctx
    }

    private func getWindowTitle(pid: pid_t?) -> String? {
        guard let pid = pid else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success else { return nil }
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowValue as! AXUIElement, kAXTitleAttribute as CFString, &titleValue) == .success else { return nil }
        return titleValue as? String
    }

    private func getBrowserURL(appName: String, bundleId: String) -> String? {
        let script: String
        switch bundleId {
        case "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac":
            script = """
            tell application "\(appName)"
                return URL of active tab of front window
            end tell
            """
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                return URL of front document
            end tell
            """
        case "company.thebrowser.Browser": // Arc
            script = """
            tell application "Arc"
                return URL of active tab of front window
            end tell
            """
        case "org.mozilla.firefox":
            // Firefox has limited AppleScript support; fall back to window title
            return nil
        default:
            return nil
        }

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let result = appleScript.executeAndReturnError(&error)
        return result.stringValue
    }
}
