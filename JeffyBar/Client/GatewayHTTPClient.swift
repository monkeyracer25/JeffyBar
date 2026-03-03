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

    /// Dedicated URLSession with generous timeouts for LLM streaming responses.
    /// - timeoutIntervalForRequest: max idle time between data packets (120s)
    /// - timeoutIntervalForResource: max total duration for a single resource (600s)
    private static let urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    var gatewayURL: String {
        UserDefaults.standard.string(forKey: "gatewayURL") ?? "http://192.168.1.131:18789"
    }

    var authToken: String {
        (try? KeychainHelper.shared.get("gatewayToken")) ?? "546eacfc0b5794006378c230bf1a670d7ce68a9f43b3afae"
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
                // timeoutInterval on the request is honoured as the per-packet idle timeout
                request.timeoutInterval = 120

                let historyMessages = conversationHistory.suffix(20).map { msg -> [String: String] in
                    ["role": msg.isUser ? "user" : "assistant", "content": msg.text]
                }
                let newUserMessage: [String: String] = ["role": "user", "content": text]

                let body: [String: Any] = [
                    "model": "anthropic/claude-opus-4-6",
                    "stream": true,
                    "user": "jonny-studio",
                    "messages": historyMessages + [newUserMessage]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)

                let (bytes, response) = try await Self.urlSession.bytes(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    appState.setLastMessageError("Invalid response")
                    return
                }

                guard httpResponse.statusCode == 200 else {
                    appState.setLastMessageError("HTTP \(httpResponse.statusCode)")
                    return
                }

                appState.connectionState = .connected

                var finalized = false
                for try await line in bytes.lines {
                    if Task.isCancelled { break }
                    guard line.hasPrefix("data: ") else { continue }
                    let data = String(line.dropFirst(6))
                    if data == "[DONE]" {
                        appState.finalizeLastMessage()
                        finalized = true
                        break
                    }
                    if let jsonData = data.data(using: .utf8),
                       let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: jsonData),
                       let content = chunk.choices.first?.delta.content {
                        appState.appendToLastMessage(delta: content)
                    }
                }

                // Only finalize here if [DONE] was never received (e.g. stream cut short)
                if !Task.isCancelled && !finalized {
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

    /// Fetch a file's contents from the Mini by asking a lightweight model to read it.
    /// Returns the raw file content extracted from the response's code fence, or nil on failure.
    func fetchFileContent(path: String) async -> String? {
        guard let url = URL(string: gatewayURL + "/v1/chat/completions") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "anthropic/claude-haiku-4-5",
            "stream": false,
            "user": "jeffybar-file-fetch",
            "messages": [
                ["role": "user", "content": "Read the file at \(path) and return its complete contents inside a single code fence. No commentary, just the fenced content."]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await Self.urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return nil }

            // Parse non-streaming response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                // Extract content from code fence
                return extractCodeFenceContent(from: content)
            }
        } catch {
            print("[JeffyBar] File fetch error: \(error.localizedDescription)")
        }
        return nil
    }

    /// Extract the content inside the first code fence from a response string.
    private func extractCodeFenceContent(from text: String) -> String? {
        let lines = text.components(separatedBy: "\n")
        var inFence = false
        var content: [String] = []

        for line in lines {
            if line.hasPrefix("```") {
                if !inFence {
                    inFence = true
                    continue
                } else {
                    // End of fence — return what we have
                    return content.joined(separator: "\n")
                }
            } else if inFence {
                content.append(line)
            }
        }

        // If no code fence found, return the whole text (the model might have just dumped it)
        if content.isEmpty && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text
        }
        return content.isEmpty ? nil : content.joined(separator: "\n")
    }

    func checkConnection(gatewayURL: String, token: String) async -> Bool {
        guard let url = URL(string: gatewayURL + "/v1/models") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (_, response) = try await Self.urlSession.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
