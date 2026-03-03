import Foundation

struct AIModel: Identifiable, Hashable, Codable {
    let id: String          // API identifier
    let displayName: String
    let shortName: String
    let provider: String

    static let allModels: [AIModel] = [
        AIModel(id: "anthropic/claude-opus-4-6",       displayName: "Claude Opus 4.6",   shortName: "Opus",    provider: "Anthropic"),
        AIModel(id: "anthropic/claude-sonnet-4-6",     displayName: "Claude Sonnet 4.6", shortName: "Sonnet",  provider: "Anthropic"),
        AIModel(id: "anthropic/claude-haiku-4-5",      displayName: "Claude Haiku 4.5",  shortName: "Haiku",   provider: "Anthropic"),
        AIModel(id: "openai-codex/gpt-5.3-codex",     displayName: "GPT 5.3 Codex",     shortName: "GPT 5.3", provider: "OpenAI"),
        AIModel(id: "google-gemini-cli/gemini-3-pro-preview", displayName: "Gemini 3 Pro", shortName: "Gemini", provider: "Google"),
    ]

    static let `default` = allModels[0]

    static func fromId(_ id: String) -> AIModel {
        allModels.first { $0.id == id } ?? .default
    }
}
