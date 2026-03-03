enum KnownService: String, CaseIterable {
    case gmail, googleDocs, googleSheets, googleSlides
    case github, githubPR, githubIssue
    case notion, slack, linear, figma, jira, stackOverflow

    var displayName: String {
        switch self {
        case .gmail: return "Gmail"
        case .googleDocs: return "Google Docs"
        case .googleSheets: return "Google Sheets"
        case .googleSlides: return "Google Slides"
        case .github: return "GitHub"
        case .githubPR: return "GitHub PR"
        case .githubIssue: return "GitHub Issue"
        case .notion: return "Notion"
        case .slack: return "Slack"
        case .linear: return "Linear"
        case .figma: return "Figma"
        case .jira: return "Jira"
        case .stackOverflow: return "Stack Overflow"
        }
    }

    static func detect(from url: String) -> KnownService? {
        let u = url.lowercased()
        if u.contains("mail.google.com") { return .gmail }
        if u.contains("docs.google.com/document") { return .googleDocs }
        if u.contains("docs.google.com/spreadsheets") { return .googleSheets }
        if u.contains("docs.google.com/presentation") { return .googleSlides }
        if u.contains("github.com") && u.contains("/pull/") { return .githubPR }
        if u.contains("github.com") && u.contains("/issues/") { return .githubIssue }
        if u.contains("github.com") { return .github }
        if u.contains("notion.so") { return .notion }
        if u.contains("app.slack.com") { return .slack }
        if u.contains("linear.app") { return .linear }
        if u.contains("figma.com") { return .figma }
        if u.contains("atlassian.net") { return .jira }
        if u.contains("stackoverflow.com") { return .stackOverflow }
        return nil
    }
}
