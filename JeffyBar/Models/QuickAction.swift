import Foundation

struct QuickAction: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let icon: String     // SF Symbol name
    let prompt: String   // Template — {selection} and {url} are replaced

    static let defaultActions: [QuickAction] = [
        QuickAction(label: "Explain", icon: "lightbulb", prompt: "Explain this:\n\n{selection}"),
        QuickAction(label: "Summarize", icon: "doc.text", prompt: "Summarize this:\n\n{selection}"),
        QuickAction(label: "Code Review", icon: "checkmark.circle", prompt: "Review this code:\n\n{selection}"),
        QuickAction(label: "Fix Grammar", icon: "pencil", prompt: "Fix grammar/spelling:\n\n{selection}"),
    ]

    static let emailActions: [QuickAction] = [
        QuickAction(label: "Draft Reply", icon: "arrow.reply", prompt: "Draft a professional reply to:\n\n{selection}"),
        QuickAction(label: "Summarize", icon: "doc.text", prompt: "Summarize this email:\n\n{selection}"),
    ]

    static let codeActions: [QuickAction] = [
        QuickAction(label: "Explain", icon: "lightbulb", prompt: "Explain this code:\n\n{selection}"),
        QuickAction(label: "Fix Bug", icon: "bug", prompt: "Find and fix bugs in:\n\n{selection}"),
        QuickAction(label: "Test Cases", icon: "checkmark.square", prompt: "Write test cases for:\n\n{selection}"),
    ]

    static let githubActions: [QuickAction] = [
        QuickAction(label: "Review PR", icon: "checkmark.circle", prompt: "Review this PR:\n\n{url}"),
        QuickAction(label: "Fix Issue", icon: "wrench", prompt: "How to fix this issue:\n\n{url}"),
    ]

    static func forService(_ service: KnownService?) -> [QuickAction] {
        switch service {
        case .gmail: return emailActions
        case .github, .githubPR, .githubIssue: return githubActions
        case .googleDocs: return [
            QuickAction(label: "Edit", icon: "pencil", prompt: "Improve this text:\n\n{selection}"),
            QuickAction(label: "Summarize", icon: "doc.text", prompt: "Summarize:\n\n{selection}"),
        ]
        default: return defaultActions
        }
    }
}
