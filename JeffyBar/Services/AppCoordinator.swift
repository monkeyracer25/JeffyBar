import SwiftUI
import Combine

@MainActor @Observable
class AppCoordinator {
    let appState: AppState

    /// Stored openWindow action — set from a SwiftUI view's .task so it's always available
    var openWindowAction: ((String) -> Void)?

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        setupNotificationHandlers()
    }

    private func setupNotificationHandlers() {
        NotificationCenter.default.publisher(for: .openJeffWindow)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleOpenJeff()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .selectAndAsk)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleSelectAndAsk()
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .captureScreenshot)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.handleScreenshot()
                }
            }
            .store(in: &cancellables)
    }

    func handleOpenJeff() {
        openMainWindow()
    }

    func handleSelectAndAsk() async {
        let defaults = UserDefaults.standard
        let isSelectAndAskEnabled = defaults.object(forKey: "selectAndAskEnabled") as? Bool ?? true
        guard isSelectAndAskEnabled else { return }

        // IMPORTANT: Capture BEFORE activating JeffyBar
        let includeAppContext = defaults.object(forKey: "includeAppContext") as? Bool ?? true
        let context = includeAppContext ? AppContextManager.shared.captureCurrentContext() : nil
        let selectedText = await TextCaptureManager.shared.captureSelectedText()

        openMainWindow()

        if let text = selectedText, !text.isEmpty {
            appState.pendingSelectAndAskText = text
            appState.pendingAppContext = context
        }
    }

    func handleScreenshot() async {
        let defaults = UserDefaults.standard
        let includeScreenshots = defaults.object(forKey: "includeScreenshots") as? Bool ?? true
        guard includeScreenshots else { return }

        guard let image = await ScreenshotCaptureManager.shared.captureActiveWindow() else {
            print("Screenshot capture failed")
            return
        }

        guard let base64 = ScreenshotCaptureManager.shared.imageToBase64(image) else {
            print("Failed to encode screenshot")
            return
        }

        let includeAppContext = defaults.object(forKey: "includeAppContext") as? Bool ?? true
        let context = includeAppContext ? AppContextManager.shared.captureCurrentContext() : nil

        openMainWindow()

        appState.pendingScreenshot = base64
        appState.pendingAppContext = context
    }

    private func openMainWindow() {
        if let action = openWindowAction {
            action("main-window")
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}
