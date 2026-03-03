import SwiftUI

@main
struct JeffyBarApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var gatewayClient = GatewayHTTPClient()
    @StateObject private var wsClient = GatewayWSClient()
    @StateObject private var bonjourDiscovery = BonjourDiscovery()
    @StateObject private var conversationStore = ConversationStore.shared
    @StateObject private var contextManager = AppContextManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            ChatPopoverView()
                .environmentObject(appState)
                .environmentObject(gatewayClient)
                .environmentObject(wsClient)
                .environmentObject(bonjourDiscovery)
                .environmentObject(conversationStore)
                .environmentObject(contextManager)
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
                .environmentObject(conversationStore)
                .environmentObject(contextManager)
                .onReceive(NotificationCenter.default.publisher(for: .openJeffWindow)) { _ in
                    openWindow(id: "main-window")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .onReceive(NotificationCenter.default.publisher(for: .selectAndAsk)) { _ in
                    Task {
                        let defaults = UserDefaults.standard
                        let isSelectAndAskEnabled = defaults.object(forKey: "selectAndAskEnabled") as? Bool ?? true
                        guard isSelectAndAskEnabled else { return }

                        // IMPORTANT: Capture BEFORE activating JeffyBar
                        let includeAppContext = defaults.object(forKey: "includeAppContext") as? Bool ?? true
                        let context = includeAppContext ? AppContextManager.shared.captureCurrentContext() : nil
                        let selectedText = await TextCaptureManager.shared.captureSelectedText()

                        openWindow(id: "main-window")
                        NSApp.activate(ignoringOtherApps: true)

                        if let text = selectedText, !text.isEmpty {
                            appState.pendingSelectAndAskText = text
                            appState.pendingAppContext = context
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .captureScreenshot)) { _ in
                    Task {
                        let defaults = UserDefaults.standard
                        let includeScreenshots = defaults.object(forKey: "includeScreenshots") as? Bool ?? true
                        guard includeScreenshots else { return }

                        guard let image = await ScreenshotCaptureManager.shared.captureActiveWindow() else {
                            print("Screenshot capture failed")
                            return
                        }

                        guard let base64 = ScreenshotCaptureManager.shared.imageToBase64(image) else {
                            print("Failed to encode screenshot")
                            return
                        }

                        // Capture context (app + window title)
                        let includeAppContext = defaults.object(forKey: "includeAppContext") as? Bool ?? true
                        let context = includeAppContext ? AppContextManager.shared.captureCurrentContext() : nil

                        // Activate Jeff and populate with screenshot + context
                        openWindow(id: "main-window")
                        NSApp.activate(ignoringOtherApps: true)

                        appState.pendingScreenshot = base64
                        appState.pendingAppContext = context
                    }
                }
        }
        .defaultSize(width: 900, height: 700)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    SettingsWindowController.shared.show(
                        appState: appState,
                        gatewayClient: gatewayClient,
                        wsClient: wsClient,
                        bonjourDiscovery: bonjourDiscovery
                    )
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

    }
    // NOTE: No Settings scene — we open settings as a standalone NSWindow
    // via SettingsWindowController to avoid the SwiftUI popover+sheet dismissal bug.

    init() {
        // Register global hotkeys: ⌘+J, ⌥+Space, ⌘+Shift+J
        HotKeyManager.shared.register()

        // Request notification permission and set up categories
        NotificationManager.shared.requestPermission()
        NotificationManager.shared.setupCategories()
    }
}
