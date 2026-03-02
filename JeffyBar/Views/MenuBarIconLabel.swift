import SwiftUI

struct MenuBarIconLabel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Image(systemName: iconName)
            .symbolEffect(.variableColor.iterative.reversing, isActive: appState.isStreaming)
            .help("Jeff")
    }

    private var iconName: String {
        switch appState.connectionState {
        case .connected:
            return "bolt.fill"
        case .connecting:
            return "bolt.badge.clock.fill"
        case .error:
            return "bolt.slash.fill"
        case .disconnected:
            return "bolt"
        }
    }
}
