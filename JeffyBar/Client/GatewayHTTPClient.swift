import Foundation

struct ChatCompletionChunk: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Decodable {
        let content: String?
        let role: String?
    }
}

@MainActor
class GatewayHTTPClient: ObservableObject {
    private var currentTask: Task<Void, Never>?

    var gatewayURL: String {
        UserDefaults.standard.string(forKey: "gatewayURL") ?? "http://localhost:18789"
    }

    var authToken: String {
        (try? KeychainHelper.shared.get("gatewayToken")) ?? ""
    }

    func sendMessage(
        _ text: String,
        conversationHistory: [ChatMessage],
        appState: AppState
    ) {
        currentTask?.cancel()

        currentTask = Task {
            do {
                guard let url = URL(string: gatewayURL + "/v1/chat/completions") else {
                    appState.setLastMessageError("Invalid gateway URL")
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 120

                let historyMessages = conversationHistory.suffix(20).map { msg -> [String: String] in
                    ["role": msg.isUser ? "user" : "assistant", "content": msg.text]
                }
                let newUserMessage: [String: String] = ["role": "user", "content": text]

                let body: [String: Any] = [
                    "model": "openclaw:main",
                    "stream": true,
                    "user": "jonny-studio",
                    "messages": historyMessages + [newUserMessage]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    appState.setLastMessageError("Invalid response")
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    appState.setLastMessageError("HTTP \(httpResponse.statusCode)")
                    return
                }

                appState.connectionState = .connected

                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    guard line.hasPrefix("data: ") else { continue }
                    let data = String(line.dropFirst(6))
                    if data == "[DONE]" {
                        appState.finalizeLastMessage()
                        break
                    }
                    if let jsonData = data.data(using: .utf8),
                       let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: jsonData),
                       let content = chunk.choices.first?.delta.content {
                        appState.appendToLastMessage(delta: content)
                    }
                }

                if !Task.isCancelled {
                    appState.finalizeLastMessage()
                }

            } catch {
                if !Task.isCancelled {
                    appState.setLastMessageError(error.localizedDescription)
                }
            }
        }
    }

    func cancelRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    func checkConnection(gatewayURL: String, token: String) async -> Bool {
        guard let url = URL(string: gatewayURL + "/v1/chat/completions") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        let body: [String: Any] = [
            "model": "openclaw:main",
            "stream": false,
            "messages": [["role": "user", "content": "ping"]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
