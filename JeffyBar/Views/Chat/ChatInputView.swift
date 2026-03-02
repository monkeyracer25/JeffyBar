import SwiftUI

struct ChatInputView: View {
    @Binding var messageText: String
    @EnvironmentObject var appState: AppState
    let onSend: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message Jeff...", text: $messageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isFocused)
                .onSubmit {
                    if !appState.isStreaming && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSend()
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.controlBackgroundColor))
                )

            if appState.isStreaming {
                Button(action: onCancel) {
                    Image(systemName: "stop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear { isFocused = true }
    }
}
