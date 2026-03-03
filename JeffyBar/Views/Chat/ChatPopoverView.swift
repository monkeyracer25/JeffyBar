import SwiftUI

struct ChatPopoverView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gatewayClient: GatewayHTTPClient
    @EnvironmentObject var wsClient: GatewayWSClient
    @EnvironmentObject var bonjourDiscovery: BonjourDiscovery
    @Environment(\.openWindow) private var openWindow
    @State private var messageText = ""

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            messagesView
            Divider()
            inputView
        }
        .background(Color(.windowBackgroundColor))
    }

    private var headerView: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.yellow)
            Text("Jeff")
                .font(.headline)
            Spacer()
            connectionIndicator
            Button(action: openMainWindow) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Open in window")
            Button(action: openSettings) {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.connectionState.color)
                .frame(width: 7, height: 7)
            Text(connectionLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if appState.messages.isEmpty {
                        emptyState
                    }
                    ForEach(appState.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: appState.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: appState.messages.last?.text) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var inputView: some View {
        ChatInputView(
            messageText: $messageText,
            onSend: sendMessage,
            onCancel: cancelMessage
        )
        .padding(12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)
            Text("What can I help with?")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var connectionLabel: String {
        switch appState.connectionState {
        case .disconnected: return "Offline"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .error: return "Error"
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastId = appState.messages.last?.id {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !appState.isStreaming else { return }

        messageText = ""

        let userMsg = ChatMessage(role: .user, text: text)
        appState.addMessage(userMsg)

        let assistantMsg = ChatMessage(role: .assistant, text: "", isStreaming: true)
        appState.addMessage(assistantMsg)
        appState.isStreaming = true

        if wsClient.isConnected {
            wsClient.sendChatMessage(text)
        } else {
            let history = Array(appState.messages.dropLast(2))
            gatewayClient.sendMessage(text, conversationHistory: history, appState: appState)
        }
    }

    private func cancelMessage() {
        if wsClient.isConnected {
            wsClient.abortChat()
        } else {
            gatewayClient.cancelRequest()
        }
        appState.isStreaming = false
        if !appState.messages.isEmpty {
            let lastIndex = appState.messages.count - 1
            appState.messages[lastIndex].isStreaming = false
        }
    }

    private func openMainWindow() {
        openWindow(id: "main-window")
    }

    private func openSettings() {
        SettingsWindowController.shared.show(
            appState: appState,
            gatewayClient: gatewayClient,
            wsClient: wsClient,
            bonjourDiscovery: bonjourDiscovery
        )
    }
}
