import SwiftUI

struct ModelPickerView: View {
    @Binding var selectedModel: AIModel

    var body: some View {
        Menu {
            ForEach(grouped, id: \.key) { provider, models in
                Section(provider) {
                    ForEach(models) { model in
                        Button {
                            selectedModel = model
                        } label: {
                            HStack {
                                Text(model.displayName)
                                if model == selectedModel { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu").font(.caption)
                Text(selectedModel.shortName).font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var grouped: [(key: String, value: [AIModel])] {
        Dictionary(grouping: AIModel.allModels, by: \.provider).sorted { $0.key < $1.key }
    }
}
