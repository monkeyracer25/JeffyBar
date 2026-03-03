import SwiftUI

@main
struct JeffyBarApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var gatewayClient = GatewayHTTPClient()
    @StateObject private var wsClient = GatewayWSClient()
    @StateObject private var bonjourDiscovery = BonjourDiscovery()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            ChatPopoverView()
                .environmentObject(appState)
                .environmentObject(gatewayClient)
                .environmentObject(wsClient)
                .environmentObject(bonjourDiscovery)
                .frame(width: 420, height: 580)
                .task {
                    // Wire up httpClient reference for file fetching
                    appState.httpClient = gatewayClient
                }
        } label: {
            MenuBarIconLabel(appState: appState)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Jeff", id: "main-window") {
            MainWindowView()
                .environmentObject(appState)
                .environmentObject(gatewayClient)
                .environmentObject(wsClient)
                .environmentObject(bonjourDiscovery)
                .onReceive(NotificationCenter.default.publisher(for: .openJeffWindow)) { _ in
                    openWindow(id: "main-window")
                }
        }
        .defaultSize(width: 900, height: 700)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

    }
    // NOTE: No Settings scene — we open settings as a standalone NSWindow
    // via SettingsWindowController to avoid the SwiftUI popover+sheet dismissal bug.

    init() {
        // Register global hotkey ⌘+J
        HotKeyManager.shared.register()

        // Request notification permission
        NotificationManager.shared.requestPermission()
    }
}
