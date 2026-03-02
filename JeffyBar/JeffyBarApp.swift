import SwiftUI

@main
struct JeffyBarApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var gatewayClient = GatewayHTTPClient()

    var body: some Scene {
        MenuBarExtra {
            ChatPopoverView()
                .environmentObject(appState)
                .environmentObject(gatewayClient)
                .frame(width: 420, height: 580)
        } label: {
            MenuBarIconLabel(appState: appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(gatewayClient)
        }
    }
}
