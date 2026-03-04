import Foundation
import SwiftUI

@MainActor
class GatewayWSClient: ObservableObject {
    @Published var isConnected = false
    @Published var isStreaming = false

    private var webSocket: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var messageCounter = 0
    private var deviceIdentity: DeviceIdentity?
    private var pendingRequests: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private var receiveTask: Task<Void, Never>?

    weak var appState: AppState?

    private var gatewayURL: String = ""
    private var authToken: String = ""

    func connect(gatewayURL: String, token: String, appState: AppState) {
        self.gatewayURL = gatewayURL
        self.authToken = token
        self.appState = appState
        self.deviceIdentity = DeviceIdentity.loadOrCreate()

        Task {
            await connectWebSocket()
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        isConnected = false
    }

    // MARK: - Public API

    func sendChatMessage(_ text: String, model: String? = nil) {
        guard isConnected else { return }
        let id = nextId()
        var params: [String: Any] = ["message": text]
        if let model = model {
            params["model"] = model
        }
        let req: [String: Any] = [
            "type": "req",
            "id": id,
            "method": "chat.send",
            "params": params
        ]
        sendFrame(req)
        isStreaming = true
    }

    func abortChat() {
        guard isConnected else { return }
        let req: [String: Any] = [
            "type": "req",
            "id": nextId(),
            "method": "chat.abort",
            "params": [:] as [String: Any]
        ]
        sendFrame(req)
        isStreaming = false
    }

    func loadHistory() {
        guard isConnected else { return }
        let id = nextId()
        let req: [String: Any] = [
            "type": "req",
            "id": id,
            "method": "chat.history",
            "params": [:] as [String: Any]
        ]
        sendFrame(req)
    }

    // MARK: - Connection

    private func connectWebSocket() async {
        let wsURLString = gatewayURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")

        guard let wsURL = URL(string: wsURLString) else {
            appState?.connectionState = .error("Invalid URL")
            return
        }

        appState?.connectionState = .connecting

        let session = URLSession(configuration: .default)
        self.urlSession = session
        let ws = session.webSocketTask(with: wsURL)
        self.webSocket = ws
        ws.resume()

        receiveTask = Task {
            await receiveLoop()
        }
    }

    private func receiveLoop() async {
        guard let ws = webSocket else { return }

        while !Task.isCancelled {
            do {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    handleFrame(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handleFrame(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled {
                    isConnected = false
                    appState?.connectionState = .disconnected
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if !Task.isCancelled {
                        await connectWebSocket()
                    }
                }
                return
            }
        }
    }

    // MARK: - Frame Handling

    private func handleFrame(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "event":
            handleEvent(json)
        case "res":
            handleResponse(json)
        default:
            break
        }
    }

    private func handleEvent(_ json: [String: Any]) {
        guard let event = json["event"] as? String,
              let payload = json["payload"] as? [String: Any] else { return }

        switch event {
        case "connect.challenge":
            let nonce = payload["nonce"] as? String ?? ""
            sendConnectRequest(nonce: nonce)

        case "chat":
            handleChatEvent(payload)

        case "agent", "health", "tick", "presence":
            break

        default:
            break
        }
    }

    private func handleChatEvent(_ payload: [String: Any]) {
        let delta = payload["delta"] as? String
        let done = payload["done"] as? Bool ?? false

        if let content = delta, !content.isEmpty {
            appState?.appendToLastMessage(delta: content)
        }

        if done {
            appState?.finalizeLastMessage()
            isStreaming = false
        }
    }

    private func handleResponse(_ json: [String: Any]) {
        guard let id = json["id"] as? String else { return }
        let ok = json["ok"] as? Bool ?? false
        let payload = json["payload"] as? [String: Any] ?? [:]

        if let payloadType = payload["type"] as? String, payloadType == "hello-ok" {
            isConnected = true
            appState?.connectionState = .connected
            loadHistory()
            return
        }

        if let messages = payload["messages"] as? [[String: Any]] {
            handleHistoryResponse(messages)
            return
        }

        if let continuation = pendingRequests.removeValue(forKey: id) {
            if ok {
                continuation.resume(returning: payload)
            } else {
                let errorMsg = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                continuation.resume(throwing: NSError(domain: "GatewayWS", code: 0, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
            }
        }
    }

    private func handleHistoryResponse(_ messages: [[String: Any]]) {
        let chatMessages = messages.compactMap { msg -> ChatMessage? in
            guard let role = msg["role"] as? String,
                  let content = msg["content"] as? String else { return nil }
            let messageRole: ChatMessage.MessageRole = role == "user" ? .user : .assistant
            return ChatMessage(role: messageRole, text: content)
        }

        if !chatMessages.isEmpty {
            appState?.messages = chatMessages
        }
    }

    // MARK: - Connect Handshake

    private func sendConnectRequest(nonce: String) {
        guard let identity = deviceIdentity else { return }

        let signedAtMs = Int64(Date().timeIntervalSince1970 * 1000)
        let signature = identity.signPayload(
            nonce: nonce,
            token: authToken,
            signedAtMs: signedAtMs
        )

        let connectReq: [String: Any] = [
            "type": "req",
            "id": nextId(),
            "method": "connect",
            "params": [
                "minProtocol": 3,
                "maxProtocol": 3,
                "client": [
                    "id": "jeffybar",
                    "version": "1.0.0",
                    "platform": "macos",
                    "mode": "ui"
                ] as [String: Any],
                "role": "operator",
                "scopes": ["operator.read", "operator.write"],
                "caps": [] as [Any],
                "commands": [] as [Any],
                "permissions": [:] as [String: Any],
                "auth": ["token": authToken] as [String: Any],
                "locale": "en-US",
                "userAgent": "JeffyBar/1.0",
                "device": [
                    "id": identity.deviceId,
                    "publicKey": identity.publicKeyBase64URL,
                    "signature": signature,
                    "signedAt": signedAtMs,
                    "nonce": nonce
                ] as [String: Any]
            ] as [String: Any]
        ]

        sendFrame(connectReq)
    }

    // MARK: - Helpers

    private func nextId() -> String {
        messageCounter += 1
        return String(messageCounter)
    }

    private func sendFrame(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(text)) { error in
            if let error = error {
                print("WS send error: \(error)")
            }
        }
    }
}
