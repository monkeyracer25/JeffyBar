import GRDB; import Foundation

struct MessageRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "message"
    var id: String; var conversationId: String; var role: String
    var content: String; var timestamp: Date; var modelId: String?
    static let conversation = belongsTo(ConversationRecord.self)

    init(id: String = UUID().uuidString, conversationId: String, role: String,
         content: String, timestamp: Date = Date(), modelId: String? = nil) {
        self.id = id; self.conversationId = conversationId; self.role = role
        self.content = content; self.timestamp = timestamp; self.modelId = modelId
    }
}
