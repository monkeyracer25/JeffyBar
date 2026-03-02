import AppKit
import SwiftUI

@MainActor
class WindowManager: ObservableObject {
    static let shared = WindowManager()

    @Published var currentArtifact: Artifact? = nil
    private var artifactPanel: ArtifactPanel?

    private init() {}

    func showArtifact(_ artifact: Artifact) {
        currentArtifact = artifact

        if artifactPanel == nil {
            let panel = ArtifactPanel()
            artifactPanel = panel
        }

        let hostingView = NSHostingView(
            rootView: ArtifactPanelView(artifact: artifact, windowManager: self)
        )
        artifactPanel?.contentView = hostingView

        if !(artifactPanel?.isVisible ?? false) {
            artifactPanel?.center()
        }
        artifactPanel?.makeKeyAndOrderFront(nil)
    }

    func closePanel() {
        artifactPanel?.close()
    }

    func saveArtifact(_ artifact: Artifact) -> URL? {
        guard let content = artifact.contentString else { return nil }

        let jeffDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Jeff")

        try? FileManager.default.createDirectory(at: jeffDir, withIntermediateDirectories: true)

        let fileURL = jeffDir.appendingPathComponent(artifact.suggestedFilename)
        try? content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
