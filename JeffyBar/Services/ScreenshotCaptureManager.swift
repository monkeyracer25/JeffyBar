import ScreenCaptureKit
import CoreImage
import AppKit

@MainActor
class ScreenshotCaptureManager: ObservableObject {
    static let shared = ScreenshotCaptureManager()
    @Published var isCapturing = false

    private init() {}

    /// Capture the active window (simple one-shot)
    /// Skips JeffyBar's own windows — captures the most recent non-JeffyBar window
    func captureActiveWindow() async -> NSImage? {
        isCapturing = true
        defer { isCapturing = false }

        do {
            // Get available shareable content
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            let myBundleId = Bundle.main.bundleIdentifier ?? "com.jeffybar.JeffyBar"

            // Find the first non-JeffyBar window (ordered by layer/recency)
            guard let targetWindow = content.windows.first(where: { window in
                window.owningApplication?.bundleIdentifier != myBundleId
                && window.frame.width > 100
                && window.frame.height > 100
            }) else {
                print("[Screenshot] No suitable window found")
                return nil
            }

            print("[Screenshot] Capturing: \(targetWindow.owningApplication?.applicationName ?? "unknown") - \(targetWindow.title ?? "untitled")")

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
