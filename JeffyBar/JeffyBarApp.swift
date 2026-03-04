import SwiftUI

@main
struct JeffyBarApp: App {
    @StateObject private var appState: AppState
    @StateObject private var gatewayClient = GatewayHTTPClient()
    @StateObject private var wsClient = GatewayWSClient()
    @StateObject private var bonjourDiscovery = BonjourDiscovery()
    @StateObject private var conversationStore = ConversationStore.shared
    @StateObject private var contextManager = AppContextManager.shared
    @Environment(\.openWindow) private var openWindow

    @State private var coordinator: AppCoordinator

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        _coordinator = State(initialValue: AppCoordinator(appState: state))

        // Register global hotkeys: ⌘+J, ⌥+Space, ⌘+Shift+J
        HotKeyManager.shared.register()

        // Request notification permission and set up categories
        NotificationManager.shared.requestPermission()
        NotificationManager.shared.setupCategories()
    }

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
                    // Wire openWindow action into coordinator so hotkeys can open the main window
                    coordinator.openWindowAction = { [openWindow] id in
                        openWindow(id: id)
                    }
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
}
