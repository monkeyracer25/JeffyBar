import GRDB
import Foundation

class DatabaseManager {
    static let shared: DatabaseManager = {
        do { return try DatabaseManager() }
        catch { fatalError("DB init failed: \(error)") }
    }()

    let dbQueue: DatabaseQueue

    private init() throws {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("JeffyBar", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbQueue = try DatabaseQueue(path: dir.appendingPathComponent("jeffybar.sqlite").path)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            try db.create(table: "conversation") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text)
                t.column("modelId", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("isPinned", .boolean).notNull().defaults(to: false)
                t.column("messageCount", .integer).notNull().defaults(to: 0)
                t.column("lastMessagePreview", .text)
            }
            try db.create(table: "message") { t in
                t.primaryKey("id", .text).notNull()
                t.column("conversationId", .text).notNull()
                    .references("conversation", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("modelId", .text)
            }
            try db.create(table: "artifact") { t in
                t.primaryKey("id", .text).notNull()
                t.column("messageId", .text).notNull()
                    .references("message", onDelete: .cascade)
                t.column("conversationId", .text).notNull()
                t.column("type", .text).notNull()
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("language", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_msg_conv", on: "message", columns: ["conversationId"])
            try db.create(index: "idx_msg_ts", on: "message", columns: ["timestamp"])
            try db.create(index: "idx_art_msg", on: "artifact", columns: ["messageId"])
            try db.create(index: "idx_conv_updated", on: "conversation", columns: ["updatedAt"])
        }
        return m
    }
}
