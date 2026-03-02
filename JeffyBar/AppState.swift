import SwiftUI

enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case error(String)

    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .error: return .red
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming: Bool = false
    @Published var gatewayURL: String = UserDefaults.standard.string(forKey: "gatewayURL") ?? "http://localhost:18789"

    func addMessage(_ message: ChatMessage) {
        messages.append(message)
    }

    func appendToLastMessage(delta: String) {
        guard !messages.isEmpty else { return }
        let lastIndex = messages.count - 1
        messages[lastIndex].text += delta
    }

    func finalizeLastMessage() {
        guard !messages.isEmpty else { return }
        let lastIndex = messages.count - 1
        messages[lastIndex].isStreaming = false
        isStreaming = false
    }

    func setLastMessageError(_ error: String) {
        guard !messages.isEmpty else { return }
        let lastIndex = messages.count - 1
        messages[lastIndex].text = "Error: \(error)"
        messages[lastIndex].isStreaming = false
        isStreaming = false
        connectionState = .error(error)
    }
}
