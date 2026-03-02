import SwiftUI

struct CodeArtifactView: View {
    let code: String
    let language: String
    @State private var copied = false

    var body: some View {
        ScrollView([.horizontal, .vertical]) {
            HStack(alignment: .top) {
                // Line numbers
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { index, _ in
                        Text("\(index + 1)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 32, alignment: .trailing)
                            .padding(.vertical, 1)
                    }
                }
                .padding(.leading, 16)

                Divider()

                // Code
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 1)
                    }
                }
                .padding(.leading, 12)
                .padding(.trailing, 16)

                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
        }
        .textSelection(.enabled)
        .background(Color(.textBackgroundColor))
    }

    private var lines: [String] {
        code.components(separatedBy: "\n")
    }
}
