import ScreenCaptureKit
import CoreImage
import AppKit

@MainActor
class ScreenshotCaptureManager: ObservableObject {
    static let shared = ScreenshotCaptureManager()
    @Published var isCapturing = false

    private init() {}

    /// Capture the active window (simple one-shot)
    func captureActiveWindow() async -> NSImage? {
        isCapturing = true
        defer { isCapturing = false }

        do {
            // Get available shareable content
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            // Get the frontmost application
            guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                print("[Screenshot] No frontmost app")
                return nil
            }

            // Find the window for this application
            guard let targetWindow = content.windows.first(where: { window in
                window.owningApplication?.bundleIdentifier == frontApp.bundleIdentifier
            }) else {
                print("[Screenshot] No window found for \(frontApp.localizedName ?? "app")")
                return nil
            }

            // Create a content filter for this single window
            let filter = SCContentFilter(desktopIndependentWindow: targetWindow)

            // Configure the capture (match window size)
            let config = SCStreamConfiguration()
            config.width = Int(targetWindow.frame.width)
            config.height = Int(targetWindow.frame.height)
            config.showsCursor = true  // Include cursor in capture

            // Capture the image
            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

            // Convert to NSImage
            let nsImage = NSImage(cgImage: cgImage, size: targetWindow.frame.size)
            return nsImage
        } catch {
            print("[Screenshot] Capture failed: \(error)")
            return nil
        }
    }

    /// Convert NSImage to base64 PNG for API transmission
    func imageToBase64(_ image: NSImage) -> String? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return pngData.base64EncodedString()
    }
}
