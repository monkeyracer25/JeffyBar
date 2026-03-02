import SwiftUI
import MarkdownUI

struct MarkdownArtifactView: View {
    let text: String

    var body: some View {
        ScrollView {
            Markdown(text)
                .markdownTheme(.gitHub)
                .textSelection(.enabled)
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
