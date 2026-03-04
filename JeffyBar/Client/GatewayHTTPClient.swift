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
        UserDefaults.standard.string(forKey: "gatewayURL") ?? "http://localhost:18789"
    }

    var authToken: String {
        (try? KeychainHelper.shared.get("gatewayToken")) ?? ""
    }

    func sendMessage(
        _ text: String,
        conversationHistory: [ChatMessage],
        model: AIModel,
        screenshot: String? = nil,
        appContext: AppContext? = nil,
        appState: AppState
    ) {
        currentTask?.cancel()

        currentTask = Task {
            do {
                guard let url = URL(string: gatewayURL + "/v1/chat/completions") else {
                    appState.setLastMessageError("Invalid gateway URL")
                    return
                }
                let token = authToken.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !token.isEmpty else {
                    appState.setLastMessageError("Missing gateway token")
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 120

                let historyMessages = conversationHistory.suffix(20).map { msg -> [String: Any] in
                    ["role": msg.isUser ? "user" : "assistant", "content": msg.text]
                }

                // Build user message content — use content array if screenshot is present
                let newUserMessage: [String: Any]
                if screenshot != nil || appContext != nil {
                    var contentArray: [[String: Any]] = []

                    // Text content with optional context prefix
                    var userContent = text
                    if let context = appContext {
                        userContent = context.asSystemContext() + "\n\n" + text
                    }
                    contentArray.append(["type": "text", "text": userContent])

                    // Add screenshot if available
                    if let base64 = screenshot {
                        contentArray.append([
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/png;base64,\(base64)"
                            ]
                        ])
                    }

                    newUserMessage = ["role": "user", "content": contentArray]
                } else {
                    newUserMessage = ["role": "user", "content": text]
                }

                let body: [String: Any] = [
                    "model": model.id,
                    "stream": true,
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

    /// The workspace prefix to strip from absolute paths when building the file-server URL.
    private static let workspacePrefix = "/Users/jeffyjeff/.openclaw/workspace/"

    /// Fetch a file's contents from the Mini's file server (port 18790).
    /// The file server serves files from the workspace directory.
    func fetchFileContent(path: String) async -> String? {
        print("[JeffyBar] fetchFileContent called with path: \(path)")

        // 1. Extract the host from gatewayURL (e.g. "http://192.168.1.131:18789" → "192.168.1.131")
        guard let gatewayComponents = URLComponents(string: gatewayURL),
              let host = gatewayComponents.host, !host.isEmpty else {
            print("[JeffyBar] fetchFileContent: could not extract host from gatewayURL: \(gatewayURL)")
            return nil
        }

        // 2. Strip the workspace prefix to get the relative path
        var relativePath = path
        if relativePath.hasPrefix(Self.workspacePrefix) {
            relativePath = String(relativePath.dropFirst(Self.workspacePrefix.count))
        } else if relativePath.hasPrefix("/Users/jeffyjeff/.openclaw/workspace") {
            // Without trailing slash
            relativePath = String(relativePath.dropFirst("/Users/jeffyjeff/.openclaw/workspace".count))
            if relativePath.hasPrefix("/") { relativePath = String(relativePath.dropFirst()) }
        }
        // Percent-encode the relative path for the URL
        let encodedPath = relativePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? relativePath

        // 3. Build the file server URL
        let fileServerURL = "http://\(host):18790/\(encodedPath)"
        print("[JeffyBar] fetchFileContent: fetching from \(fileServerURL)")

        guard let url = URL(string: fileServerURL) else {
            print("[JeffyBar] fetchFileContent: invalid URL: \(fileServerURL)")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        do {
            let (data, response) = try await Self.urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("[JeffyBar] fetchFileContent: non-HTTP response")
                return nil
            }

            print("[JeffyBar] fetchFileContent: HTTP \(httpResponse.statusCode), \(data.count) bytes")

            guard httpResponse.statusCode == 200 else {
                print("[JeffyBar] fetchFileContent: server returned \(httpResponse.statusCode)")
                return nil
            }

            let content = String(data: data, encoding: .utf8)
            print("[JeffyBar] fetchFileContent: got \(content?.count ?? 0) chars")
            return content
        } catch {
            print("[JeffyBar] fetchFileContent error: \(error.localizedDescription)")
            return nil
        }
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
