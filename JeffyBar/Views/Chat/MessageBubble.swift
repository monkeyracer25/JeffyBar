import SwiftUI
import MarkdownUI

struct MessageBubble: View {
    let message: ChatMessage
    @EnvironmentObject var appState: AppState

    /// Strip code fences from the display text when artifacts exist
    var displayText: String {
        guard appState.messageArtifacts[message.id] != nil else {
            return message.text
        }
        // Remove ```lang ... ``` blocks, keep everything else
        var result = message.text
        let pattern = "```[a-zA-Z]*\\n[\\s\\S]*?```"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }
        // Clean up extra whitespace
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.isEmpty {
            result = "Here you go 👇"
        }
        return result
    }

    var body: some View {
        if message.isUser {
            HStack {
                Spacer(minLength: 40)
                Text(message.text)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        } else {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if message.text.isEmpty && message.isStreaming {
                        StreamingIndicator()
                    } else {
                        Markdown(displayText.isEmpty ? " " : displayText)
                            .markdownTheme(.gitHub)
                            .textSelection(.enabled)
                        if message.isStreaming {
                            StreamingIndicator()
                        }
                    }

                    // Artifact buttons
                    if let artifacts = appState.messageArtifacts[message.id] {
                        ForEach(artifacts) { artifact in
                            Button(action: {
                                WindowManager.shared.showArtifact(artifact)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: artifact.type.icon)
                                        .font(.caption)
                                    Text(artifact.title)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // File fetching indicator
                    if appState.isFetchingFile {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Fetching file from Mini…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer(minLength: 40)
            }
        }
    }
}
