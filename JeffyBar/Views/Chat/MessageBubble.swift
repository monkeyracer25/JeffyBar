import SwiftUI
import MarkdownUI

struct MessageBubble: View {
    let message: ChatMessage

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
                        Markdown(message.text.isEmpty ? " " : message.text)
                            .markdownTheme(.gitHub)
                            .textSelection(.enabled)
                        if message.isStreaming {
                            StreamingIndicator()
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
