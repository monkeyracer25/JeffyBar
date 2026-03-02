import AppKit

class ArtifactPanel: NSPanel {
    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 640, height: 520)
        super.init(
            contentRect: contentRect,
            styleMask: [
                .titled,
                .closable,
                .resizable,
                .fullSizeContentView,
                .nonactivatingPanel
            ],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true

        // Remember position between sessions
        setFrameAutosaveName("JeffArtifactPanel")

        // Min size
        minSize = NSSize(width: 400, height: 300)
    }
}
