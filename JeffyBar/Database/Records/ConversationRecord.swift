import GRDB; import Foundation

struct ConversationRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "conversation"
    var id: String; var title: String?; var modelId: String
    var createdAt: Date; var updatedAt: Date; var isPinned: Bool
    var messageCount: Int; var lastMessagePreview: String?
    static let messages = hasMany(MessageRecord.self)

    init(id: String = UUID().uuidString, title: String? = nil, modelId: String,
         createdAt: Date = Date(), updatedAt: Date = Date(),
         isPinned: Bool = false, messageCount: Int = 0, lastMessagePreview: String? = nil) {
        self.id = id; self.title = title; self.modelId = modelId
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.isPinned = isPinned; self.messageCount = messageCount
        self.lastMessagePreview = lastMessagePreview
    }
}
