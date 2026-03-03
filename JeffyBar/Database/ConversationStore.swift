import GRDB; import Foundation

@MainActor
class ConversationStore: ObservableObject {
    static let shared = ConversationStore()
    @Published var conversations: [ConversationRecord] = []
    @Published var currentConversationId: String?
    private let db = DatabaseManager.shared.dbQueue
    private init() { loadConversations() }

    func loadConversations() {
        conversations = (try? db.read { db in
            try ConversationRecord
                .order(Column("isPinned").desc, Column("updatedAt").desc)
                .fetchAll(db)
        }) ?? []
    }

    func createConversation(modelId: String) -> ConversationRecord {
        let c = ConversationRecord(modelId: modelId)
        try? db.write { db in try c.insert(db) }
        currentConversationId = c.id
        loadConversations()
        return c
    }

    func deleteConversation(_ id: String) {
        _ = try? db.write { db in try ConversationRecord.deleteOne(db, id: id) }
        if currentConversationId == id { currentConversationId = nil }
        loadConversations()
    }

    func loadMessages(for convId: String) -> [MessageRecord] {
        (try? db.read { db in
            try MessageRecord.filter(Column("conversationId") == convId)
                .order(Column("timestamp").asc).fetchAll(db)
        }) ?? []
    }

    func saveMessage(_ msg: MessageRecord) {
        try? db.write { db in
            try msg.insert(db)
            try ConversationRecord.filter(id: msg.conversationId).updateAll(db, [
                Column("updatedAt").set(to: Date()),
                Column("messageCount").set(to: Column("messageCount") + 1),
                Column("lastMessagePreview").set(to: String(msg.content.prefix(100)))
            ])
        }
        loadConversations()
    }

    func updateTitle(_ convId: String, title: String) {
        try? db.write { db in
            try ConversationRecord.filter(id: convId).updateAll(db, Column("title").set(to: title))
        }
        loadConversations()
    }

    func search(query: String) -> [ConversationRecord] {
        (try? db.read { db in
            let ids = try String.fetchAll(db, sql:
                "SELECT DISTINCT conversationId FROM message WHERE content LIKE ?",
                arguments: ["%\(query)%"])
            return try ConversationRecord
                .filter(ids.contains(Column("id")) || Column("title").like("%\(query)%"))
                .order(Column("updatedAt").desc).fetchAll(db)
        }) ?? []
    }

    func autoTitle(_ convId: String, firstMessage: String) {
        let clean = firstMessage.replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let title = clean.count <= 50 ? clean :
            (clean.prefix(50).lastIndex(of: " ").map { String(clean[..<$0]) + "\u{2026}" }
             ?? String(clean.prefix(50)) + "\u{2026}")
        updateTitle(convId, title: title)
    }
}
