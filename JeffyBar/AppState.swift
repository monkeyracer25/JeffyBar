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
    @Published var isFetchingFile: Bool = false

    /// Reference to the HTTP client for file fetching (set by the app on init)
    var httpClient: GatewayHTTPClient?

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
            // 1. Parse inline code fence artifacts
            let artifacts = ArtifactParser.extractArtifacts(from: message.text, messageId: message.id)
            if !artifacts.isEmpty {
                messageArtifacts[message.id] = artifacts
                // Auto-open the first artifact in the floating panel
                WindowManager.shared.showArtifact(artifacts[0])
            }

            // 2. Detect file paths for remote fetching (only if no inline artifacts found)
            if artifacts.isEmpty {
                let filePaths = ArtifactParser.extractFilePaths(from: message.text)
                if !filePaths.isEmpty {
                    fetchRemoteFiles(filePaths, forMessage: message)
                }
            }

            // Notify if app not in foreground
            if !NSApp.isActive {
                let preview = message.text.components(separatedBy: "\n").first ?? message.text
                NotificationManager.shared.notifyResponseReady(preview: preview)
            }
        }
    }

    /// Fetch file contents from the Mini via the gateway and create artifacts
    private func fetchRemoteFiles(_ paths: [DetectedFilePath], forMessage message: ChatMessage) {
        guard let client = httpClient else { return }

        isFetchingFile = true

        Task {
            var fetchedArtifacts: [Artifact] = []

            for filePath in paths.prefix(3) {  // Limit to 3 files max
                if let content = await client.fetchFileContent(path: filePath.path) {
                    let artifact: Artifact
                    if filePath.language == "html" && (content.contains("<html") || content.contains("<!DOCTYPE") || content.contains("<div")) {
                        artifact = Artifact(
                            type: .html(content),
                            title: filePath.displayName,
                            sourceMessageId: message.id
                        )
                    } else if filePath.language == "markdown" {
                        artifact = Artifact(
                            type: .markdown(content),
                            title: filePath.displayName,
                            sourceMessageId: message.id
                        )
                    } else {
                        artifact = Artifact(
                            type: .code(content, language: filePath.language),
                            title: filePath.displayName,
                            sourceMessageId: message.id
                        )
                    }
                    fetchedArtifacts.append(artifact)
                }
            }

            await MainActor.run {
                isFetchingFile = false
                if !fetchedArtifacts.isEmpty {
                    let existing = messageArtifacts[message.id] ?? []
                    messageArtifacts[message.id] = existing + fetchedArtifacts
                    // Auto-open the first fetched artifact
                    WindowManager.shared.showArtifact(fetchedArtifacts[0])
                }
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
