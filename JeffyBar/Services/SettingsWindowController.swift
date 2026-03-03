import AppKit
import SwiftUI

/// Opens the Settings UI in a standalone NSWindow — not a sheet.
/// This avoids the SwiftUI + MenuBarExtra popover bug where clicking in a
/// .sheet immediately dismisses the popover.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show(
        appState: AppState,
        gatewayClient: GatewayHTTPClient,
        wsClient: GatewayWSClient,
        bonjourDiscovery: BonjourDiscovery
    ) {
        // Re-use existing window if already open
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(appState)
            .environmentObject(gatewayClient)
            .environmentObject(wsClient)
            .environmentObject(bonjourDiscovery)

        let hostingController = NSHostingController(rootView: settingsView)

        let win = NSWindow(contentViewController: hostingController)
        win.title = "JeffyBar Settings"
        win.styleMask = [.titled, .closable, .miniaturizable]
        win.setFrameAutosaveName("JeffyBarSettings")
        // isReleasedWhenClosed = false so we can re-open it without crashing
        win.isReleasedWhenClosed = false

        // Center only if no saved frame exists
        if UserDefaults.standard.string(forKey: "NSWindow Frame JeffyBarSettings") == nil {
            win.center()
        }

        self.window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
