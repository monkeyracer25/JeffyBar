import GRDB; import Foundation

struct ArtifactRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "artifact"
    var id: String; var messageId: String; var conversationId: String
    var type: String; var title: String; var content: String
    var language: String?; var createdAt: Date
}
