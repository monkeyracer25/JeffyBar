import AppKit

@MainActor
class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    @Published var clipboardContents: String?

    private init() {}

    func readClipboard() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// Monitor clipboard for changes (optional — for auto-detect)
    func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let pb = NSPasteboard.general
                let current = pb.string(forType: .string)
                if current != self.clipboardContents {
                    self.clipboardContents = current
                }
            }
        }
    }
}
