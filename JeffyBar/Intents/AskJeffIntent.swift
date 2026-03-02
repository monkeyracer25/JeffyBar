import AppIntents
import Foundation

struct AskJeffIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Jeff"
    static var description = IntentDescription("Send a message to Jeff and get a response")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Message")
    var message: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Use HTTP client to get a non-streaming response
        guard let url = URL(string: (UserDefaults.standard.string(forKey: "gatewayURL") ?? "http://localhost:18789") + "/v1/chat/completions") else {
            throw IntentError.custom("Invalid gateway URL")
        }

        let token = (try? KeychainHelper.shared.get("gatewayToken")) ?? ""

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("main", forHTTPHeaderField: "x-openclaw-agent-id")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": "openclaw:main",
            "stream": false,
            "user": "jonny-shortcuts",
            "messages": [["role": "user", "content": message]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let first = choices.first,
           let messageDict = first["message"] as? [String: Any],
           let content = messageDict["content"] as? String {
            return .result(value: content)
        }

        throw IntentError.custom("Failed to get response")
    }

    enum IntentError: Error, CustomLocalizedStringResourceConvertible {
        case custom(String)

        var localizedStringResource: LocalizedStringResource {
            switch self {
            case .custom(let msg): return LocalizedStringResource(stringLiteral: msg)
            }
        }
    }
}
