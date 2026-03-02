import Foundation

enum ArtifactType: Equatable {
    case code(String, language: String)  // code content, language
    case html(String)                     // HTML string
    case markdown(String)                 // Markdown text
    case pdf(URL)                         // file URL

    var displayName: String {
        switch self {
        case .code(_, let lang): return lang.capitalized
        case .html: return "HTML"
        case .markdown: return "Markdown"
        case .pdf: return "PDF"
        }
    }

    var icon: String {
        switch self {
        case .code: return "doc.text"
        case .html: return "globe"
        case .markdown: return "text.alignleft"
        case .pdf: return "doc.fill"
        }
    }
}

struct Artifact: Identifiable, Equatable {
    let id: UUID
    let type: ArtifactType
    let title: String
    let sourceMessageId: UUID?

    init(id: UUID = UUID(), type: ArtifactType, title: String, sourceMessageId: UUID? = nil) {
        self.id = id
        self.type = type
        self.title = title
        self.sourceMessageId = sourceMessageId
    }

    var contentString: String? {
        switch type {
        case .code(let content, _): return content
        case .html(let content): return content
        case .markdown(let content): return content
        case .pdf: return nil
        }
    }

    var suggestedFilename: String {
        let sanitized = title.replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        switch type {
        case .code(_, let lang):
            let ext = languageExtension(lang)
            return "\(sanitized).\(ext)"
        case .html: return "\(sanitized).html"
        case .markdown: return "\(sanitized).md"
        case .pdf: return "\(sanitized).pdf"
        }
    }

    private func languageExtension(_ lang: String) -> String {
        switch lang.lowercased() {
        case "swift": return "swift"
        case "python", "py": return "py"
        case "javascript", "js": return "js"
        case "typescript", "ts": return "ts"
        case "html": return "html"
        case "css": return "css"
        case "json": return "json"
        case "yaml", "yml": return "yml"
        case "bash", "sh", "shell": return "sh"
        case "rust": return "rs"
        case "go": return "go"
        default: return "txt"
        }
    }
}
