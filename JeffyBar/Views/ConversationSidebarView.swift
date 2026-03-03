import SwiftUI

struct ConversationSidebarView: View {
    @EnvironmentObject var store: ConversationStore
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search\u{2026}", text: $searchText).textFieldStyle(.plain)
            }.padding(8).background(Color(.controlBackgroundColor))
            Divider()
            Button { let c = store.createConversation(modelId: appState.selectedModel.id)
                appState.loadConversation(c.id)
            } label: { Label("New Chat", systemImage: "plus.bubble").frame(maxWidth: .infinity, alignment: .leading) }
            .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            ScrollView { LazyVStack(spacing: 2) {
                ForEach(searchText.isEmpty ? store.conversations : store.search(query: searchText)) { conv in
                    ConversationRow(conv: conv, selected: conv.id == store.currentConversationId)
                        .onTapGesture { appState.loadConversation(conv.id) }
                        .contextMenu {
                            Button("Delete", role: .destructive) { store.deleteConversation(conv.id) }
                        }
                }
            }.padding(.vertical, 4) }
        }.frame(width: 240)
    }
}

struct ConversationRow: View {
    let conv: ConversationRecord; let selected: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conv.title ?? "New conversation").font(.system(size: 13, weight: selected ? .semibold : .regular)).lineLimit(1)
            if let p = conv.lastMessagePreview { Text(p).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Color.accentColor.opacity(0.15) : Color.clear))
        .padding(.horizontal, 4)
    }
}
