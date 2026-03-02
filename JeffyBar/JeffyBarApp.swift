import SwiftUI

@main
struct JeffyBarApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var gatewayClient = GatewayHTTPClient()
    @StateObject private var wsClient = GatewayWSClient()

    var body: some Scene {
        MenuBarExtra {
            ChatPopoverView()
                .environmentObject(appState)
                .environmentObject(gatewayClient)
                .environmentObject(wsClient)
                .frame(width: 420, height: 580)
        } label: {
            MenuBarIconLabel(appState: appState)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Jeff", id: "main-window") {
            MainWindowView()
                .environmentObject(appState)
                .environmentObject(gatewayClient)
                .environmentObject(wsClient)
        }
        .defaultSize(width: 900, height: 700)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(gatewayClient)
                .environmentObject(wsClient)
        }
    }
}
