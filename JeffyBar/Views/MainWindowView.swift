import SwiftUI
import MarkdownUI

struct MainWindowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var gatewayClient: GatewayHTTPClient
    @EnvironmentObject var wsClient: GatewayWSClient
    @State private var messageText = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            Divider()
            messagesView
            Divider()
            ChatInputView(
                messageText: $messageText,
                onSend: sendMessage,
                onCancel: cancelMessage
            )
            .padding(16)
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Jeff")
        .onAppear {
            let url = UserDefaults.standard.string(forKey: "gatewayURL") ?? ""
            let token = (try? KeychainHelper.shared.get("gatewayToken")) ?? ""
            if !url.isEmpty && !token.isEmpty && !wsClient.isConnected {
                wsClient.connect(gatewayURL: url, token: token, appState: appState)
            }
        }
    }

    private var toolbarView: some View {
        HStack {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.yellow)
            Text("Jeff")
                .font(.headline)
            Spacer()
            connectionBadge
            if appState.isStreaming {
                Button("Stop") {
                    cancelMessage()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundStyle(.red)
            }
            Button(action: clearHistory) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Clear conversation")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var connectionBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(appState.connectionState.color)
                .frame(width: 7, height: 7)
            Text(wsClient.isConnected ? "WebSocket" : "HTTP")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if appState.messages.isEmpty {
                        emptyState
                    }
                    ForEach(appState.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: appState.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: appState.messages.last?.text) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
            Text("Jeff is ready")
                .font(.title2)
                .fontWeight(.semibold)
            Text("What can I help with?")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
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

    private func clearHistory() {
        appState.messages = []
    }
}
