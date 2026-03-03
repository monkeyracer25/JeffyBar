import SwiftUI

struct QuickActionsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contextManager: AppContextManager
    @Binding var messageText: String

    var body: some View {
        let context = contextManager.currentContext
        let actions = QuickAction.forService(context?.service)

        if !actions.isEmpty {
            HStack(spacing: 6) {
                ForEach(actions) { action in
                    Button {
                        var prompt = action.prompt
                        prompt = prompt.replacingOccurrences(of: "{selection}", with: "")
                        prompt = prompt.replacingOccurrences(of: "{url}", with: context?.browserURL ?? "")
                        messageText = prompt
                    } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}
