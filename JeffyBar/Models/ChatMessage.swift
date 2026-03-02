import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    var text: String
    let timestamp: Date
    var isStreaming: Bool

    enum MessageRole {
        case user
        case assistant
    }

    init(id: UUID = UUID(), role: MessageRole, text: String, timestamp: Date = Date(), isStreaming: Bool = false) {
        self.id = id
        self.role = role
        self.text = text
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }

    var isUser: Bool { role == .user }
}
