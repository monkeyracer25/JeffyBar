import Foundation

struct ArtifactParser {
    static let minCodeLength = 10  // Promote code blocks above this length

    static func extractArtifacts(from text: String, messageId: UUID) -> [Artifact] {
        var artifacts: [Artifact] = []

        // 1. Check for full HTML documents
        if text.contains("<!DOCTYPE") || (text.contains("<html") && text.contains("</html>")) {
            let title = extractHTMLTitle(from: text) ?? "HTML Document"
            artifacts.append(Artifact(
                type: .html(text),
                title: title,
                sourceMessageId: messageId
            ))
            return artifacts  // If it's a full HTML doc, treat the whole thing as an artifact
        }

        // 2. Extract fenced code blocks
        let lines = text.components(separatedBy: "\n")
        var inCodeBlock = false
        var currentLanguage = ""
        var currentCode: [String] = []
        var blockCount = 0

        for line in lines {
            if line.hasPrefix("```") {
                if !inCodeBlock {
                    // Start of code block
                    inCodeBlock = true
                    currentLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    currentCode = []
                } else {
                    // End of code block
                    inCodeBlock = false
                    let code = currentCode.joined(separator: "\n")

                    if code.count >= minCodeLength {
                        blockCount += 1
                        let lang = currentLanguage.isEmpty ? "text" : currentLanguage

                        // If it's HTML, treat as HTML artifact (renders in WebView)
                        if lang == "html" && (code.contains("<html") || code.contains("<!DOCTYPE") || code.contains("<div") || code.contains("<body")) {
                            let title = extractHTMLTitle(from: code) ?? "HTML Document"
                            artifacts.append(Artifact(
                                type: .html(code),
                                title: title,
                                sourceMessageId: messageId
                            ))
                        } else {
                            let title = blockCount == 1 ? "\(lang.capitalized) Code" : "\(lang.capitalized) Code \(blockCount)"
                            artifacts.append(Artifact(
                                type: .code(code, language: lang),
                                title: title,
                                sourceMessageId: messageId
                            ))
                        }
                    }
                    currentLanguage = ""
                    currentCode = []
                }
            } else if inCodeBlock {
                currentCode.append(line)
            }
        }

        // 3. Check for HTML fragments (incomplete HTML with multiple tags)
        if artifacts.isEmpty {
            let htmlTagCount = countHTMLTags(in: text)
            if htmlTagCount >= 3 && (text.contains("<div") || text.contains("<section") || text.contains("<article")) {
                artifacts.append(Artifact(
                    type: .html(text),
                    title: "HTML Content",
                    sourceMessageId: messageId
                ))
            }
        }

        return artifacts
    }

    private static func extractHTMLTitle(from html: String) -> String? {
        if let range = html.range(of: "<title>"),
           let endRange = html.range(of: "</title>") {
            let start = range.upperBound
            let end = endRange.lowerBound
            if start < end {
                return String(html[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func countHTMLTags(in text: String) -> Int {
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: "<[a-zA-Z][^>]*>", options: .regularExpression, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<text.endIndex
            if count > 10 { break }
        }
        return count
    }
}
