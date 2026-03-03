import ApplicationServices
import AppKit

@MainActor
class TextCaptureManager {
    static let shared = TextCaptureManager()
    private init() {}

    // PRIMARY: Accessibility API — fast, clean
    func getSelectedTextViaAX() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }

        var text: CFTypeRef?
        // swiftlint:disable:next force_cast
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &text) == .success,
              let str = text as? String, !str.isEmpty else { return nil }
        return str
    }

    // FALLBACK: Simulate Cmd+C, read pasteboard, restore
    func getSelectedTextViaCmdC() async -> String? {
        let pb = NSPasteboard.general
        let prevCount = pb.changeCount
        let saved = pb.string(forType: .string)

        guard let src = CGEventSource(stateID: .hidSystemState) else { return nil }
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)

        try? await Task.sleep(nanoseconds: 150_000_000)
        let copied = pb.string(forType: .string)

        // Restore clipboard
        if pb.changeCount != prevCount {
            pb.clearContents()
            if let s = saved { pb.setString(s, forType: .string) }
        }
        guard copied != saved else { return nil }
        return copied
    }

    // Combined: AX first, Cmd+C fallback
    func captureSelectedText() async -> String? {
        if let text = getSelectedTextViaAX() { return text }
        return await getSelectedTextViaCmdC()
    }
}
