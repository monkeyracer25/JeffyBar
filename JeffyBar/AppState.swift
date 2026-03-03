import SwiftUI
import AppKit

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
    @Published var messageArtifacts: [UUID: [Artifact]] = [:]

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

        let message = messages[lastIndex]
        if !message.isUser {
            // Parse artifacts and auto-open the first one
            let artifacts = ArtifactParser.extractArtifacts(from: message.text, messageId: message.id)
            if !artifacts.isEmpty {
                messageArtifacts[message.id] = artifacts
                // Auto-open the first artifact in the floating panel
                WindowManager.shared.showArtifact(artifacts[0])
            }

            // Notify if app not in foreground
            if !NSApp.isActive {
                let preview = message.text.components(separatedBy: "\n").first ?? message.text
                NotificationManager.shared.notifyResponseReady(preview: preview)
            }
        }
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
