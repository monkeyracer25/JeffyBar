import SwiftUI

struct ArtifactPanelView: View {
    let artifact: Artifact
    let windowManager: WindowManager
    @State private var saveMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbarView
            Divider()
            contentView
        }
        .background(Color(.windowBackgroundColor))
    }

    private var toolbarView: some View {
        HStack(spacing: 12) {
            Image(systemName: artifact.type.icon)
                .foregroundStyle(.secondary)
            Text(artifact.title)
                .font(.headline)
                .lineLimit(1)
            Spacer()

            if let msg = saveMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Button("Copy") {
                copyContent()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button("Save") {
                if let _ = windowManager.saveArtifact(artifact) {
                    saveMessage = "Saved"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        saveMessage = nil
                    }
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if case .pdf(let url) = artifact.type {
                Button("Reveal") {
                    windowManager.revealInFinder(url)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Save & Reveal") {
                    if let url = windowManager.saveArtifact(artifact) {
                        windowManager.revealInFinder(url)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var contentView: some View {
        switch artifact.type {
        case .code(let code, let language):
            CodeArtifactView(code: code, language: language)

        case .html(let html):
            HTMLArtifactView(html: html)

        case .markdown(let text):
            MarkdownArtifactView(text: text)

        case .pdf(let url):
            PDFArtifactView(url: url)
        }
    }

    private func copyContent() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let content = artifact.contentString {
            pasteboard.setString(content, forType: .string)
        }
    }
}
