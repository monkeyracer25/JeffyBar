import SwiftUI
import UniformTypeIdentifiers

struct ChatInputView: View {
    @Binding var messageText: String
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contextManager: AppContextManager
    let onSend: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool
    @State private var isDropTargeted = false
    @State private var attachedFiles: [URL] = []

    var body: some View {
        VStack(spacing: 6) {
            // Quick Actions row
            QuickActionsView(messageText: $messageText)
                .environmentObject(appState)
                .environmentObject(contextManager)

            // Attached files chips
            if !attachedFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(attachedFiles, id: \.self) { url in
                            fileChip(url: url)
                        }
                    }
                }
                .frame(height: 28)
            }

            HStack(alignment: .bottom, spacing: 8) {
                ModelPickerView(selectedModel: $appState.selectedModel)

                TextField("Message Jeff...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .onSubmit {
                        if !appState.isStreaming && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            sendWithFiles()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isDropTargeted
                                ? Color.accentColor.opacity(0.1)
                                : Color(.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isDropTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                    )
                    .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                        handleDrop(providers)
                        return true
                    }

                // Clipboard paste button
                Menu {
                    Button {
                        if let clip = ClipboardManager.shared.readClipboard() {
                            messageText = clip
                        }
                    } label: {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if appState.isStreaming {
                    Button(action: onCancel) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: sendWithFiles) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .buttonStyle(.plain)
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedFiles.isEmpty)
                }
            }
        }
        .onAppear { isFocused = true }
    }

    private func fileChip(url: URL) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "doc")
                .font(.caption2)
            Text(url.lastPathComponent)
                .font(.caption2)
                .lineLimit(1)
            Button(action: { attachedFiles.removeAll { $0 == url } }) {
                Image(systemName: "xmark")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let path = String(data: data, encoding: .utf8),
                      let url = URL(string: path) else { return }
                Task { @MainActor in
                    attachedFiles.append(url)
                }
            }
        }
    }

    private func sendWithFiles() {
        var fullMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)

        if !attachedFiles.isEmpty {
            let filesList = attachedFiles.map { "- \($0.path)" }.joined(separator: "\n")
            if !fullMessage.isEmpty {
                fullMessage += "\n\nAttached files:\n\(filesList)"
            } else {
                fullMessage = "Files attached:\n\(filesList)"
            }
            attachedFiles = []
        }

        guard !fullMessage.isEmpty else { return }

        // Update messageText to the full message then call onSend
        messageText = fullMessage
        onSend()
    }
}
