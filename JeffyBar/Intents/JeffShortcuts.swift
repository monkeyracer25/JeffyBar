import AppIntents

struct JeffShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskJeffIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Tell \(.applicationName) something",
                "Hey \(.applicationName)"
            ],
            shortTitle: "Ask Jeff",
            systemImageName: "bolt.fill"
        )
    }
}
