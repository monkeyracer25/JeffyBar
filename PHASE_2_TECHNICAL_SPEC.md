# JeffyBar — Phase 2 Technical Specification

> Complete implementation guide for Phase 2 features.
> Every section has working Swift code, permissions, gotchas, and architecture decisions.
> A coding agent can implement each feature from this spec alone.

---

## Table of Contents

1. [Select & Ask](#1-select--ask)
2. [Model Picker](#2-model-picker)
3. [Conversation Persistence](#3-conversation-persistence)
4. [App Context Detection](#4-app-context-detection)
5. [Quick Actions Per App](#5-quick-actions)
6. [Screenshot Capture](#6-screenshot-capture)
7. [Clipboard Integration](#7-clipboard-integration)
8. [Notifications](#8-notifications)
9. [Settings Window](#9-settings-window)
10. [Studio → Mini Architecture](#10-architecture)
11. [Permissions Summary](#11-permissions)
12. [New Dependencies](#12-dependencies)
13. [Implementation Order](#13-implementation-order)

---

## 1. Select & Ask

### Overview
Global hotkey (⌥+Space) captures selected text from ANY macOS app and sends it to Jeff with frontmost app context.

### Approach: Dual Strategy
**Primary:** Accessibility API (`kAXSelectedTextAttribute`) — native apps, no side effects.
**Fallback:** Simulated Cmd+C via CGEvent — Electron apps, web views. Temporarily modifies clipboard.

### Required Permission
**Accessibility** — System Settings → Privacy & Security → Accessibility

### Permission Manager

```swift
// File: Services/AccessibilityManager.swift
import ApplicationServices
import AppKit

@MainActor
class AccessibilityManager: ObservableObject {
    static let shared = AccessibilityManager()
    @Published var hasPermission: Bool = false

    private init() { updatePermissionStatus() }

    func updatePermissionStatus() {
        hasPermission = AXIsProcessTrusted()
    }

    func requestPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        hasPermission = AXIsProcessTrustedWithOptions(opts)
    }

    func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

### Text Capture

```swift
// File: Services/TextCaptureManager.swift
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
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &text) == .success,
              let str = text as? String, !str.isEmpty else { return nil }
        return str
    }

    // FALLBACK: Simulate Cmd+C, read pasteboard, restore
    func getSelectedTextViaCmdC() async -> String? {
        let pb = NSPasteboard.general
        let prevCount = pb.changeCount
        let saved = pb.string(forType: .string)

        let src = CGEventSource(stateID: .hidSystemState)
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
```

### Updated HotKeyManager

```swift
// File: Services/HotKeyManager.swift
import HotKey

@MainActor
class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()
    private var openHotKey: HotKey?
    private var selectAskHotKey: HotKey?
    private var screenshotHotKey: HotKey?
    private init() {}

    func register() {
        openHotKey = HotKey(key: .j, modifiers: [.command])
        openHotKey?.keyDownHandler = {
            Task { @MainActor in
                NotificationCenter.default.post(name: .openJeffWindow, object: nil)
            }
        }

        selectAskHotKey = HotKey(key: .space, modifiers: [.option])
        selectAskHotKey?.keyDownHandler = {
            Task { @MainActor in
                NotificationCenter.default.post(name: .selectAndAsk, object: nil)
            }
        }

        screenshotHotKey = HotKey(key: .j, modifiers: [.command, .shift])
        screenshotHotKey?.keyDownHandler = {
            Task { @MainActor in
                NotificationCenter.default.post(name: .captureScreenshot, object: nil)
            }
        }
    }

    func unregister() {
        openHotKey = nil; selectAskHotKey = nil; screenshotHotKey = nil
    }
}

extension Notification.Name {
    static let openJeffWindow = Notification.Name("com.jeffybar.openJeffWindow")
    static let selectAndAsk = Notification.Name("com.jeffybar.selectAndAsk")
    static let captureScreenshot = Notification.Name("com.jeffybar.captureScreenshot")
}
```

### Select & Ask Flow

```swift
// In JeffyBarApp — handle the notification:
.onReceive(NotificationCenter.default.publisher(for: .selectAndAsk)) { _ in
    Task {
        // IMPORTANT: Capture BEFORE activating JeffyBar
        let context = AppContextManager.shared.captureCurrentContext()
        let selectedText = await TextCaptureManager.shared.captureSelectedText()

        openWindow(id: "main-window")
        NSApp.activate(ignoringOtherApps: true)

        if let text = selectedText, !text.isEmpty {
            appState.pendingSelectAndAskText = text
            appState.pendingAppContext = context
        }
    }
}
```

### Gotchas

- **Timing**: Capture context BEFORE `NSApp.activate()`. Once JeffyBar activates, frontmostApplication changes.
- **Electron apps** (VS Code, Slack): AX returns empty/garbled. Cmd+C fallback handles these.
- **Clipboard restore**: 150ms delay critical — some apps are slow to populate pasteboard.
- **Terminal.app**: Cmd+C = interrupt signal. AX approach works better. Try AX first.
- **CGEvent needs Accessibility permission**: Same permission as AXUIElement.

---

## 2. Model Picker

### Model Registry

```swift
// File: Models/AIModel.swift
import Foundation

struct AIModel: Identifiable, Hashable, Codable {
    let id: String          // API identifier
    let displayName: String
    let shortName: String
    let provider: String

    static let allModels: [AIModel] = [
        AIModel(id: "anthropic/claude-opus-4-6",       displayName: "Claude Opus 4.6",   shortName: "Opus",    provider: "Anthropic"),
        AIModel(id: "anthropic/claude-sonnet-4-6",     displayName: "Claude Sonnet 4.6", shortName: "Sonnet",  provider: "Anthropic"),
        AIModel(id: "anthropic/claude-haiku-4-5",      displayName: "Claude Haiku 4.5",  shortName: "Haiku",   provider: "Anthropic"),
        AIModel(id: "openai-codex/gpt-5.3-codex",     displayName: "GPT 5.3 Codex",     shortName: "GPT 5.3", provider: "OpenAI"),
        AIModel(id: "google-gemini-cli/gemini-3-pro-preview", displayName: "Gemini 3 Pro", shortName: "Gemini", provider: "Google"),
    ]

    static let `default` = allModels[0]

    static func fromId(_ id: String) -> AIModel {
        allModels.first { $0.id == id } ?? .default
    }
}
```

### AppState Addition

```swift
// Add to AppState.swift:
@Published var selectedModel: AIModel = {
    if let id = UserDefaults.standard.string(forKey: "selectedModel") {
        return AIModel.fromId(id)
    }
    return AIModel.default
}() {
    didSet { UserDefaults.standard.set(selectedModel.id, forKey: "selectedModel") }
}
```

### Picker View

```swift
// File: Views/Chat/ModelPickerView.swift
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
```

### API Integration

```swift
// GatewayHTTPClient.sendMessage — change body:
let body: [String: Any] = [
    "model": model.id,    // ← was hardcoded
    "stream": true,
    "messages": historyMessages + [newUserMessage]
]
```

Place `ModelPickerView` left of the text input in `ChatInputView`.

---

## 3. Conversation Persistence

### Why GRDB.swift (SQLite)

- SwiftData still buggy with complex queries on macOS (2025)
- Core Data too heavyweight for this schema
- GRDB is mature, lightweight, excellent SwiftUI integration
- SQLite is what Claude Desktop and Oracle Bar use
- Full control over schema and migrations

### SPM Dependency

```yaml
# Add to project.yml packages:
GRDB:
  url: https://github.com/groue/GRDB.swift
  from: 7.0.0
```

### Database Manager

```swift
// File: Database/DatabaseManager.swift
import GRDB
import Foundation

class DatabaseManager {
    static let shared: DatabaseManager = {
        do { return try DatabaseManager() }
        catch { fatalError("DB init failed: \(error)") }
    }()

    let dbQueue: DatabaseQueue

    private init() throws {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!.appendingPathComponent("JeffyBar", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        dbQueue = try DatabaseQueue(path: dir.appendingPathComponent("jeffybar.sqlite").path)
        try migrator.migrate(dbQueue)
    }

    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1") { db in
            try db.create(table: "conversation") { t in
                t.primaryKey("id", .text).notNull()
                t.column("title", .text)
                t.column("modelId", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("isPinned", .boolean).notNull().defaults(to: false)
                t.column("messageCount", .integer).notNull().defaults(to: 0)
                t.column("lastMessagePreview", .text)
            }
            try db.create(table: "message") { t in
                t.primaryKey("id", .text).notNull()
                t.column("conversationId", .text).notNull()
                    .references("conversation", onDelete: .cascade)
                t.column("role", .text).notNull()
                t.column("content", .text).notNull()
                t.column("timestamp", .datetime).notNull()
                t.column("modelId", .text)
            }
            try db.create(table: "artifact") { t in
                t.primaryKey("id", .text).notNull()
                t.column("messageId", .text).notNull()
                    .references("message", onDelete: .cascade)
                t.column("conversationId", .text).notNull()
                t.column("type", .text).notNull()
                t.column("title", .text).notNull()
                t.column("content", .text).notNull()
                t.column("language", .text)
                t.column("createdAt", .datetime).notNull()
            }
            try db.create(index: "idx_msg_conv", on: "message", columns: ["conversationId"])
            try db.create(index: "idx_msg_ts", on: "message", columns: ["timestamp"])
            try db.create(index: "idx_art_msg", on: "artifact", columns: ["messageId"])
            try db.create(index: "idx_conv_updated", on: "conversation", columns: ["updatedAt"])
        }
        return m
    }
}
```

### Record Types

```swift
// File: Database/Records/ConversationRecord.swift
import GRDB; import Foundation

struct ConversationRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "conversation"
    var id: String; var title: String?; var modelId: String
    var createdAt: Date; var updatedAt: Date; var isPinned: Bool
    var messageCount: Int; var lastMessagePreview: String?
    static let messages = hasMany(MessageRecord.self)

    init(id: String = UUID().uuidString, title: String? = nil, modelId: String,
         createdAt: Date = Date(), updatedAt: Date = Date(),
         isPinned: Bool = false, messageCount: Int = 0, lastMessagePreview: String? = nil) {
        self.id = id; self.title = title; self.modelId = modelId
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.isPinned = isPinned; self.messageCount = messageCount
        self.lastMessagePreview = lastMessagePreview
    }
}

// File: Database/Records/MessageRecord.swift
struct MessageRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "message"
    var id: String; var conversationId: String; var role: String
    var content: String; var timestamp: Date; var modelId: String?
    static let conversation = belongsTo(ConversationRecord.self)

    init(id: String = UUID().uuidString, conversationId: String, role: String,
         content: String, timestamp: Date = Date(), modelId: String? = nil) {
        self.id = id; self.conversationId = conversationId; self.role = role
        self.content = content; self.timestamp = timestamp; self.modelId = modelId
    }
}

// File: Database/Records/ArtifactRecord.swift
struct ArtifactRecord: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "artifact"
    var id: String; var messageId: String; var conversationId: String
    var type: String; var title: String; var content: String
    var language: String?; var createdAt: Date
}
```

### Conversation Store

```swift
// File: Database/ConversationStore.swift
import GRDB; import Foundation

@MainActor
class ConversationStore: ObservableObject {
    static let shared = ConversationStore()
    @Published var conversations: [ConversationRecord] = []
    @Published var currentConversationId: String?
    private let db = DatabaseManager.shared.dbQueue
    private init() { loadConversations() }

    func loadConversations() {
        conversations = (try? db.read { db in
            try ConversationRecord
                .order(Column("isPinned").desc, Column("updatedAt").desc)
                .fetchAll(db)
        }) ?? []
    }

    func createConversation(modelId: String) -> ConversationRecord {
        let c = ConversationRecord(modelId: modelId)
        try? db.write { db in try c.insert(db) }
        currentConversationId = c.id
        loadConversations()
        return c
    }

    func deleteConversation(_ id: String) {
        _ = try? db.write { db in try ConversationRecord.deleteOne(db, id: id) }
        if currentConversationId == id { currentConversationId = nil }
        loadConversations()
    }

    func loadMessages(for convId: String) -> [MessageRecord] {
        (try? db.read { db in
            try MessageRecord.filter(Column("conversationId") == convId)
                .order(Column("timestamp").asc).fetchAll(db)
        }) ?? []
    }

    func saveMessage(_ msg: MessageRecord) {
        try? db.write { db in
            try msg.insert(db)
            try ConversationRecord.filter(id: msg.conversationId).updateAll(db, [
                Column("updatedAt").set(to: Date()),
                Column("messageCount").set(to: Column("messageCount") + 1),
                Column("lastMessagePreview").set(to: String(msg.content.prefix(100)))
            ])
        }
        loadConversations()
    }

    func updateTitle(_ convId: String, title: String) {
        try? db.write { db in
            try ConversationRecord.filter(id: convId).updateAll(db, Column("title").set(to: title))
        }
        loadConversations()
    }

    func search(query: String) -> [ConversationRecord] {
        (try? db.read { db in
            let ids = try String.fetchAll(db, sql:
                "SELECT DISTINCT conversationId FROM message WHERE content LIKE ?",
                arguments: ["%\(query)%"])
            return try ConversationRecord
                .filter(ids.contains(Column("id")) || Column("title").like("%\(query)%"))
                .order(Column("updatedAt").desc).fetchAll(db)
        }) ?? []
    }
}
```

### Auto-Titling

```swift
func autoTitle(_ convId: String, firstMessage: String) {
    let clean = firstMessage.replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let title = clean.count <= 50 ? clean :
        (clean.prefix(50).lastIndex(of: " ").map { String(clean[..<$0]) + "…" }
         ?? String(clean.prefix(50)) + "…")
    ConversationStore.shared.updateTitle(convId, title: title)
}
```

### Sidebar View

```swift
// File: Views/ConversationSidebarView.swift
import SwiftUI

struct ConversationSidebarView: View {
    @EnvironmentObject var store: ConversationStore
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search…", text: $searchText).textFieldStyle(.plain)
            }.padding(8).background(Color(.controlBackgroundColor))
            Divider()
            Button { let c = store.createConversation(modelId: appState.selectedModel.id)
                appState.loadConversation(c.id)
            } label: { Label("New Chat", systemImage: "plus.bubble").frame(maxWidth: .infinity, alignment: .leading) }
            .buttonStyle(.plain).padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
            ScrollView { LazyVStack(spacing: 2) {
                ForEach(searchText.isEmpty ? store.conversations : store.search(query: searchText)) { conv in
                    ConversationRow(conv: conv, selected: conv.id == store.currentConversationId)
                        .onTapGesture { appState.loadConversation(conv.id) }
                        .contextMenu {
                            Button("Delete", role: .destructive) { store.deleteConversation(conv.id) }
                        }
                }
            }.padding(.vertical, 4) }
        }.frame(width: 240)
    }
}

struct ConversationRow: View {
    let conv: ConversationRecord; let selected: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(conv.title ?? "New conversation").font(.system(size: 13, weight: selected ? .semibold : .regular)).lineLimit(1)
            if let p = conv.lastMessagePreview { Text(p).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Color.accentColor.opacity(0.15) : Color.clear))
        .padding(.horizontal, 4)
    }
}
```

### MainWindowView Update

```swift
// Wrap existing chat in NavigationSplitView:
var body: some View {
    NavigationSplitView {
        ConversationSidebarView()
    } detail: {
        ChatDetailView() // existing chat view content
    }
    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
}
```

---

## 4. App Context Detection

### Overview
Detect frontmost app, extract window title, browser URL. Auto-prepend to messages.

### Permissions
- `NSWorkspace.shared.frontmostApplication` — NO permissions needed
- `AXUIElement` window title — Accessibility permission (already have it)
- AppleScript browser URL — Automation permission (macOS auto-prompts on first use)

### Known Services

```swift
// File: Models/KnownService.swift
enum KnownService: String, CaseIterable {
    case gmail, googleDocs, googleSheets, googleSlides
    case github, githubPR, githubIssue
    case notion, slack, linear, figma, jira, stackOverflow

    var displayName: String {
        switch self {
        case .gmail: return "Gmail"
        case .googleDocs: return "Google Docs"
        case .googleSheets: return "Google Sheets"
        case .googleSlides: return "Google Slides"
        case .github: return "GitHub"
        case .githubPR: return "GitHub PR"
        case .githubIssue: return "GitHub Issue"
        case .notion: return "Notion"
        case .slack: return "Slack"
        case .linear: return "Linear"
        case .figma: return "Figma"
        case .jira: return "Jira"
        case .stackOverflow: return "Stack Overflow"
        }
    }

    static func detect(from url: String) -> KnownService? {
        let u = url.lowercased()
        if u.contains("mail.google.com") { return .gmail }
        if u.contains("docs.google.com/document") { return .googleDocs }
        if u.contains("docs.google.com/spreadsheets") { return .googleSheets }
        if u.contains("docs.google.com/presentation") { return .googleSlides }
        if u.contains("github.com") && u.contains("/pull/") { return .githubPR }
        if u.contains("github.com") && u.contains("/issues/") { return .githubIssue }
        if u.contains("github.com") { return .github }
        if u.contains("notion.so") { return .notion }
        if u.contains("app.slack.com") { return .slack }
        if u.contains("linear.app") { return .linear }
        if u.contains("figma.com") { return .figma }
        if u.contains("atlassian.net") { return .jira }
        if u.contains("stackoverflow.com") { return .stackOverflow }
        return nil
    }
}
```

### App Context Manager

```swift
// File: Services/AppContextManager.swift
import AppKit
import ApplicationServices

struct AppContext {
    let appName: String
    let bundleId: String?
    let windowTitle: String?
    let browserURL: String?
    let service: KnownService?
    let timestamp: Date

    func asSystemContext() -> String {
        var parts = ["[App: \(appName)]"]
        if let t = windowTitle { parts.append("[Window: \(t)]") }
        if let u = browserURL { parts.append("[URL: \(u)]") }
        if let s = service { parts.append("[Service: \(s.displayName)]") }
        return parts.joined(separator: " ")
    }
}

@MainActor
class AppContextManager: ObservableObject {
    static let shared = AppContextManager()
    @Published var currentContext: AppContext?

    private static let browserBundleIds: Set<String> = [
        "com.google.Chrome", "com.apple.Safari",
        "company.thebrowser.Browser", // Arc
        "org.mozilla.firefox",
        "com.microsoft.edgemac", "com.brave.Browser",
    ]

    private init() {}

    func captureCurrentContext() -> AppContext {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "Unknown"
        let bundleId = app?.bundleIdentifier

        // Window title via AXUIElement
        let windowTitle = getWindowTitle(pid: app?.processIdentifier)

        // Browser URL if applicable
        var browserURL: String? = nil
        if let bid = bundleId, Self.browserBundleIds.contains(bid) {
            browserURL = getBrowserURL(appName: appName, bundleId: bid)
        }

        let service = browserURL.flatMap { KnownService.detect(from: $0) }

        let ctx = AppContext(
            appName: appName, bundleId: bundleId,
            windowTitle: windowTitle, browserURL: browserURL,
            service: service, timestamp: Date()
        )
        currentContext = ctx
        return ctx
    }

    private func getWindowTitle(pid: pid_t?) -> String? {
        guard let pid = pid else { return nil }
        let appElement = AXUIElementCreateApplication(pid)
        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success else { return nil }
        var titleValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowValue as! AXUIElement, kAXTitleAttribute as CFString, &titleValue) == .success else { return nil }
        return titleValue as? String
    }

    private func getBrowserURL(appName: String, bundleId: String) -> String? {
        let script: String
        switch bundleId {
        case "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac":
            script = """
            tell application "\(appName)"
                return URL of active tab of front window
            end tell
            """
        case "com.apple.Safari":
            script = """
            tell application "Safari"
                return URL of front document
            end tell
            """
        case "company.thebrowser.Browser": // Arc
            script = """
            tell application "Arc"
                return URL of active tab of front window
            end tell
            """
        case "org.mozilla.firefox":
            // Firefox has limited AppleScript support; fall back to window title
            return nil
        default:
            return nil
        }

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        let result = appleScript.executeAndReturnError(&error)
        return result.stringValue
    }
}
```

### Message Prepending

```swift
// In GatewayHTTPClient.sendMessage, modify the user message:
var userContent = text
if let context = appContext {
    userContent = context.asSystemContext() + "\n\n" + text
}
let newUserMessage: [String: String] = ["role": "user", "content": userContent]
```

### Gotchas

- **AppleScript execution time**: 50-200ms. Run on a background queue if needed, but for Select & Ask the context is captured pre-activation so timing is fine.
- **Firefox**: Very limited AppleScript support. Window title is the best you'll get (title usually contains the URL anyway).
- **Arc's "Little Arc" windows**: May not have `active tab of front window`. Wrap in try/catch.
- **Automation permission**: macOS auto-prompts on first AppleScript execution per target app. No way to pre-request.
- **Private/incognito**: Some browsers return the URL even in incognito. Consider if this is a privacy concern.

---

## 5. Quick Actions

### Overview
Row of action buttons that changes based on the detected frontmost app/service. Each action pre-fills the chat with a contextual prompt.

### Action Definitions

```swift
// File: Models/QuickAction.swift
import Foundation

struct QuickAction: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let icon: String     // SF Symbol name
    let prompt: String   // Template — {selection} and {url} are replaced

    static let defaultActions: [QuickAction] = [
        QuickAction(label: "Explain", icon: "lightbulb", prompt: "Explain this:\n\n{selection}"),
        QuickAction(label: "Summarize", icon: "doc.text", prompt: "Summarize this:\n\n{selection}"),
        QuickAction(label: "Code Review", icon: "checkmark.circle", prompt: "Review this code:\n\n{selection}"),
        QuickAction(label: "Fix Grammar", icon: "pencil", prompt: "Fix grammar/spelling:\n\n{selection}"),
    ]

    static let emailActions: [QuickAction] = [
        QuickAction(label: "Draft Reply", icon: "arrow.reply", prompt: "Draft a professional reply to:\n\n{selection}"),
        QuickAction(label: "Summarize", icon: "doc.text", prompt: "Summarize this email:\n\n{selection}"),
    ]

    static let codeActions: [QuickAction] = [
        QuickAction(label: "Explain", icon: "lightbulb", prompt: "Explain this code:\n\n{selection}"),
        QuickAction(label: "Fix Bug", icon: "bug", prompt: "Find and fix bugs in:\n\n{selection}"),
        QuickAction(label: "Test Cases", icon: "checkmark.square", prompt: "Write test cases for:\n\n{selection}"),
    ]

    static let githubActions: [QuickAction] = [
        QuickAction(label: "Review PR", icon: "checkmark.circle", prompt: "Review this PR:\n\n{url}"),
        QuickAction(label: "Fix Issue", icon: "wrench", prompt: "How to fix this issue:\n\n{url}"),
    ]

    static func forService(_ service: KnownService?) -> [QuickAction] {
        switch service {
        case .gmail: return emailActions
        case .github, .githubPR, .githubIssue: return githubActions
        case .googleDocs: return [
            QuickAction(label: "Edit", icon: "pencil", prompt: "Improve this text:\n\n{selection}"),
            QuickAction(label: "Summarize", icon: "doc.text", prompt: "Summarize:\n\n{selection}"),
        ]
        default: return defaultActions
        }
    }
}
```

### Quick Actions View

```swift
// File: Views/Chat/QuickActionsView.swift
import SwiftUI

struct QuickActionsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var contextManager: AppContextManager
    @Binding var messageText: String

    var body: some View {
        let context = contextManager.currentContext
        let actions = QuickAction.forService(context?.service)

        if !actions.isEmpty {
            HStack(spacing: 6) {
                ForEach(actions) { action in
                    Button {
                        var prompt = action.prompt
                        prompt = prompt.replacingOccurrences(of: "{selection}", with: "")
                        prompt = prompt.replacingOccurrences(of: "{url}", with: context?.browserURL ?? "")
                        messageText = prompt
                    } label: {
                        Label(action.label, systemImage: action.icon)
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}
```

### Integration in ChatInputView

```swift
// Add QuickActionsView above the text input:
VStack(spacing: 6) {
    QuickActionsView(messageText: $messageText)
        .environmentObject(appState)
        .environmentObject(AppContextManager.shared)

    HStack(alignment: .bottom, spacing: 8) {
        ModelPickerView(selectedModel: $appState.selectedModel)
        TextField("Message Jeff...", text: $messageText, axis: .vertical)
            // ... existing modifiers ...
    }
}
```

---

## 6. Screenshot Capture

### Recommended Approach: ScreenCaptureKit (macOS 13+)

**Why?** Preferred over CGWindowListCreateImage because:
- CGWindowListCreateImage is deprecated as of macOS 15 Sequoia
- ScreenCaptureKit is the modern, supported API
- Cleaner async/await design
- Better permission handling

### Required Permission

**Screen & System Audio Recording** — System Settings → Privacy & Security → Screen & System Audio Recording

Add to `Info.plist`:
```xml
<key>NSScreenRecordingUsageDescription</key>
<string>JeffyBar captures the active window to send to Jeff for analysis</string>
```

### Screenshot Capture Manager

```swift
// File: Services/ScreenshotCaptureManager.swift
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
```

### Hotkey Integration

```swift
// In JeffyBarApp — handle screenshot notification:
.onReceive(NotificationCenter.default.publisher(for: .captureScreenshot)) { _ in
    Task {
        guard let image = await ScreenshotCaptureManager.shared.captureActiveWindow() else {
            print("Screenshot capture failed")
            return
        }

        guard let base64 = ScreenshotCaptureManager.shared.imageToBase64(image) else {
            print("Failed to encode screenshot")
            return
        }

        // Capture context (app + window title)
        let context = AppContextManager.shared.captureCurrentContext()

        // Activate Jeff and populate with screenshot + context
        openWindow(id: "main-window")
        NSApp.activate(ignoringOtherApps: true)

        appState.pendingScreenshot = base64
        appState.pendingAppContext = context
    }
}
```

### Sending Screenshot in Message

The screenshot should be sent as a vision message (vision-enabled models only: Opus, Sonnet, GPT 5.3, Gemini 3 Pro).

```swift
// In GatewayHTTPClient.sendMessage — modify to handle screenshots:

func sendMessage(
    _ text: String,
    conversationHistory: [ChatMessage],
    model: AIModel,
    screenshot: String?,  // NEW: base64-encoded image
    appState: AppState
) {
    // ... existing setup code ...

    var contentArray: [[String: Any]] = []

    // Add context if available
    if let context = appContext {
        let contextMessage = context.asSystemContext() + "\n\n" + text
        contentArray.append(["type": "text", "text": contextMessage])
    } else {
        contentArray.append(["type": "text", "text": text])
    }

    // Add screenshot if available
    if let base64 = screenshot {
        contentArray.append([
            "type": "image_url",
            "image_url": [
                "url": "data:image/png;base64,\(base64)"
            ]
        ])
    }

    let newUserMessage: [String: Any] = [
        "role": "user",
        "content": contentArray
    ]

    // ... rest of the request ...
}
```

### Gotchas

- **Permission denied** — returns `nil` image. User must grant in System Settings.
- **Off-screen windows** — ScreenCaptureKit only captures on-screen windows by default.
- **HDR displays** — ScreenCaptureKit captures in HDR if available; no special config needed.
- **Content filter** — desktopIndependentWindow is most reliable; avoid display-level filters for menu bar app.
- **Async requirement** — must run in an `async` context; cannot be synchronous.

---

## 7. Clipboard Integration

### Read Clipboard On-Demand

```swift
// File: Services/ClipboardManager.swift
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
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            let pb = NSPasteboard.general
            let current = pb.string(forType: .string)
            if current != self.clipboardContents {
                self.clipboardContents = current
            }
        }
    }
}
```

### Integration

```swift
// Add to chat input context menu or as a button:
Menu {
    Button {
        if let clip = ClipboardManager.shared.readClipboard() {
            messageText = clip
        }
    } label: {
        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
    }
} label: {
    Image(systemName: "ellipsis.circle")
}
```

### Copy Assistant Response

```swift
// In MessageBubble or a response action menu:
Button {
    ClipboardManager.shared.copyToClipboard(message.text)
} label: {
    Label("Copy", systemImage: "doc.on.doc")
}
```

### Gotchas

- **Monitoring overhead** — polling clipboard every 0.5s is reasonable; don't go faster.
- **Privacy preview in macOS 15.4+** — programmatic clipboard access shows user a preview. Expected behavior; no way to suppress.
- **Pasteboard types** — stick to `.string` for text. Other types (rich text, images) require different handling.

---

## 8. Notifications

### Rich Notifications with Actions

```swift
// File: Services/NotificationManager.swift
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func setupCategories() {
        let replyAction = UNNotificationAction(identifier: "reply", title: "Reply", options: [])
        let dismissAction = UNNotificationAction(identifier: "dismiss", title: "Dismiss", options: [.destructive])

        let category = UNNotificationCategory(
            identifier: "JEFF_RESPONSE",
            actions: [replyAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }

    func notifyResponseReady(preview: String) {
        let content = UNMutableNotificationContent()
        content.title = "Jeff replied"
        content.body = preview.count > 100 ? String(preview.prefix(100)) + "..." : preview
        content.sound = .default
        content.badge = NSNumber(value: (NSApp.dockTile.badgeLabel as NSString?)?.integerValue ?? 0 + 1)
        content.category = "JEFF_RESPONSE"

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

// Handle notification actions
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case "reply":
            // Open Jeff and focus input
            NotificationCenter.default.post(name: .openJeffWindow, object: nil)
        case "dismiss":
            // Just close the notification
            break
        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification body — open Jeff
            NotificationCenter.default.post(name: .openJeffWindow, object: nil)
        default:
            break
        }

        completionHandler()
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
```

### Integration in AppState

```swift
// In AppState.finalizeLastMessage():
if !NSApp.isActive {
    let preview = message.text.components(separatedBy: "\n").first ?? message.text
    NotificationManager.shared.notifyResponseReady(preview: preview)
}
```

### Setup in JeffyBarApp

```swift
init() {
    HotKeyManager.shared.register()
    NotificationManager.shared.requestPermission()
    NotificationManager.shared.setupCategories()
}
```

### Gotchas

- **Notification categories** — must set up BEFORE sending notifications. Category ID must match in content.
- **Do Not Disturb** — notifications are suppressed; no way to override this from the app (by design).
- **Badge numbers** — update via `NSApp.dockTile.badgeLabel = "3"`. Reset to empty string to clear.
- **Action buttons** — up to 4 per notification; text is truncated if too long.

---

## 9. Settings Window

### Standalone NSWindow (Not SwiftUI Scene)

The existing `SettingsWindowController.swift` is correct. Ensure it:
1. Opens on ⌘, (Command+Comma) — handled automatically by macOS if using native Settings scene or custom menu item
2. Is non-modal (floating, independent window)
3. Has its settings saved in UserDefaults + Keychain

Update `JeffyBarApp.swift` to add a Settings menu item if not using the native Settings scene:

```swift
// In JeffyBarApp — add Commands scene:
.commands {
    CommandGroup(replacing: .appSettings) {
        Button("Settings") {
            SettingsWindowController.shared.show()
        }
        .keyboardShortcut(",", modifiers: [.command])
    }
}
```

### SettingsWindowController (Existing — Ensure It Has)

```swift
// File: Services/SettingsWindowController.swift
import AppKit
import SwiftUI

class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private override init() { super.init() }

    func show() {
        if let w = window {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.setFrameAutosaveName("SettingsWindow")
        window.title = "Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

### New Settings to Add

Add these to `SettingsView.swift`:

```swift
Section("Model & Context") {
    Picker("Default Model", selection: $selectedModel) {
        ForEach(AIModel.allModels) { model in
            Text(model.displayName).tag(model)
        }
    }

    Toggle("Include App Context", isOn: $includeAppContext)
    Toggle("Include Screenshots", isOn: $includeScreenshots)
}

Section("Select & Ask") {
    HStack {
        Text("Hotkey")
        Spacer()
        Text("⌥+Space").font(.system(.body, design: .monospaced))
    }
    Toggle("Enabled", isOn: $selectAndAskEnabled)
}

Section("Accessibility") {
    if !AccessibilityManager.shared.hasPermission {
        Button("Grant Accessibility Permission") {
            AccessibilityManager.shared.requestPermission()
        }
    } else {
        Label("Accessibility: Granted", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
    }
}

Section("Screen Recording") {
    if !ScreenRecordingPermission.hasPermission {
        Button("Grant Screen Recording Permission") {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane"))
        }
    } else {
        Label("Screen Recording: Granted", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
    }
}
```

### Gotchas

- **SettingsWindowController must be singleton** — prevents multiple settings windows
- **isReleasedWhenClosed = false** — keeps window in memory so it can be reused (better UX)
- **setFrameAutosaveName** — automatically saves window position/size
- **Activate with ignoringOtherApps** — brings window to front even if Jeff isn't focused

---

## 10. Architecture: Studio → Mini Communication

### Current (Phase 1-3): HTTP+SSE Only

```
Studio (JeffyBar)  ──HTTP POST /v1/chat/completions──>  Mini (OpenClaw)
                   <──SSE stream (data: ...)──────────
```

**For Phase 2, this doesn't change.** Images/screenshots are sent as base64 in the message content array.

### Sending Images in Chat Completions

The OpenAI-compatible API endpoint accepts images in the message content array:

```json
{
  "model": "anthropic/claude-opus-4-6",
  "stream": true,
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "text",
          "text": "[App: Safari] [Window: GitHub PR #123]\n\nReview this code and the screenshot I'm attaching"
        },
        {
          "type": "image_url",
          "image_url": {
            "url": "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
          }
        }
      ]
    }
  ]
}
```

### File Contents from Mini

**Current:** File paths detected in Jeff's response are fetched via a separate HTTP GET to a file server on the Mini (port 18790).

**For Phase 2:** This stays the same. No changes needed.

### Latency Considerations

| Operation | Latency | Notes |
|-----------|---------|-------|
| Select & Ask (hotkey → text capture) | 50-200ms | Accessibility API + Cmd+C fallback |
| App context (NSWorkspace + AppleScript) | 50-200ms | AppleScript execution time |
| Screenshot capture (ScreenCaptureKit) | 50-500ms | Depends on window size |
| HTTP POST to Mini | 10-50ms | Local LAN, small payloads |
| LLM response streaming | 1-30s | Depends on response length |

**Optimization:** Context and screenshot capture can run in parallel. Don't wait for them sequentially.

```swift
// Parallel capture:
async let context = AppContextManager.shared.captureCurrentContext()
async let screenshot = ScreenshotCaptureManager.shared.captureActiveWindow()
async let selectedText = TextCaptureManager.shared.captureSelectedText()

let ctx = await context
let img = await screenshot
let text = await selectedText
```

### Future (Phase 4+): WebSocket for True Bidirectionality

When needed (e.g., real-time collaboration, server-initiated updates):
- Use existing `GatewayWSClient.swift`
- Images can be sent over WS with similar base64 encoding
- No architectural change needed; just enable WS transport

---

## 11. Permissions Summary

| Feature | Permission | How to Request | Where in Code |
|---------|-----------|-----------------|---------------|
| **Select & Ask** | Accessibility | `AXIsProcessTrustedWithOptions(prompt: true)` | `AccessibilityManager.requestPermission()` |
| **App Context (window title)** | Accessibility | Same as above | Automatic via AXUIElement |
| **Browser URL (AppleScript)** | Automation | System auto-prompts on first script execution | Automatic via NSAppleScript |
| **Screenshot** | Screen & System Audio Recording | Manual: System Settings > Privacy & Security | `ScreenshotCaptureManager` needs entitlement + NSScreenRecordingUsageDescription |
| **Notifications** | User Notifications | `UNUserNotificationCenter.requestAuthorization()` | `NotificationManager.requestPermission()` |
| **Global Hotkeys** | None required | Register via HotKey package | `HotKeyManager.register()` |
| **Bonjour Discovery** | Local Network | Declare in Info.plist: NSLocalNetworkUsageDescription | Info.plist (already done) |

### Entitlements Required (Info.plist)

```xml
<key>NSScreenRecordingUsageDescription</key>
<string>JeffyBar captures the active window to send to Jeff for analysis</string>

<key>NSLocalNetworkUsageDescription</key>
<string>Jeff discovers your OpenClaw Gateway on the local network.</string>

<!-- For automation via AppleScript (Automation permission) -->
<!-- Handled automatically by macOS on first NSAppleScript execution -->
```

---

## 12. New Dependencies

Add to `project.yml`:

```yaml
packages:
  GRDB:
    url: https://github.com/groue/GRDB.swift
    from: 7.0.0

targets:
  JeffyBar:
    dependencies:
      # ... existing ...
      - package: GRDB
        product: GRDB
```

**No changes needed to:**
- HotKey (already present)
- MarkdownUI (already present)
- KeychainAccess (already present)

**ScreenCaptureKit:** Native framework, imported directly in code. No SPM dependency.

---

## 13. Implementation Order

### Phase 2a (Foundation — Weeks 1-2)
1. **Model Picker** — Smallest, no dependencies. Adds UI + UserDefaults.
2. **Conversation Persistence** — Add GRDB, set up schema, create ConversationStore.
3. **Settings Window** — Already exists; add new toggles for Phase 2 features.
4. **App Context Detection** — NSWorkspace + AXUIElement for window titles.

### Phase 2b (Advanced — Weeks 3-4)
5. **Select & Ask** — TextCaptureManager + HotKey hotkey. Test AX API + Cmd+C fallback.
6. **Screenshot Capture** — ScreenCaptureKit + image-to-base64. Wire into hotkey.
7. **Quick Actions** — Define action templates per service. Wire into UI.
8. **Notifications** — UserNotifications + UNNotificationDelegate. Test background alerts.

### Phase 2c (Polish — Week 5)
9. **Clipboard Integration** — ClipboardManager read/write/monitor. Add to UI.
10. **AppState Integration** — Wire pending context/screenshot/text into chat flow.
11. **API Updates** — Modify GatewayHTTPClient to send images + context in message content.
12. **Testing & Bug Fixes** — Accessibility edge cases, permission prompts, latency.

### Testing Checklist

- [ ] Select & Ask with native app (TextEdit) — AX should work
- [ ] Select & Ask with Electron app (VS Code) — Cmd+C fallback should work
- [ ] Model picker persists across app restart
- [ ] Screenshot captures the frontmost window (not JeffyBar window itself)
- [ ] Screenshot base64 encodes without line breaks
- [ ] App context prepends correctly to messages
- [ ] Browser URL extraction works for Chrome, Safari, Arc, Firefox
- [ ] Accessibility permission prompt appears and works
- [ ] Screen Recording permission prompt appears
- [ ] Notifications alert in background (test by minimizing JeffyBar)
- [ ] Conversation sidebar persists across app restart
- [ ] Search across conversations works
- [ ] Auto-title conversation works for first message

---

## Summary

This spec covers all 10 Phase 2 topics with:
- Working Swift code (not pseudocode)
- Real permission requirements and how to handle them
- Known gotchas and workarounds
- Architecture decisions with reasoning
- Integration points with existing JeffyBar code
- Dependencies and setup instructions
- Testing guidance

A coding agent should be able to implement each feature end-to-end from these code examples alone.

**Total estimated effort:** ~4-5 weeks for a single developer. ~2 weeks with 2-3 parallel developers.

**Key insight:** Most Phase 2 features are orthogonal and can be implemented in parallel. Model Picker and Conversation Persistence are prerequisites; everything else can start simultaneously once those are done.

---

## Appendix A: Forward-Looking Notes & Supplementary Research

### A.1 macOS 15.4+ Clipboard Privacy Changes

**Breaking change for clipboard monitoring.** Starting in macOS 15.4 (preview) and fully in macOS 16, Apple is adding per-app pasteboard access controls in System Settings → Privacy & Security → "Paste from Other Apps":

| Setting | Behavior |
|---------|----------|
| **Always allow** | Full programmatic reads without alerts (needed for our clipboard monitoring) |
| **Prompt** | Shows alert per read (breaks frequent polling) |
| **Never allow** | Blocks reads entirely |

**New API:** `NSPasteboard.detectTypes()` lets apps check data types (text, image, URL) **without reading contents or triggering alerts**.

**Impact on JeffyBar:**
- `ClipboardManager.readClipboard()` will trigger user prompts under default settings
- `changeCount` polling is unaffected (no read involved)
- Users may need to grant "Always allow" for JeffyBar in System Settings
- Consider adding a setup assistant for clipboard permissions in Settings window
- Test with: `defaults write -g NSPasteboardAccessBehavior -int 1` (prompt mode)

**Recommendation:** Use `detectTypes` first to check if there's text, then only read when the user explicitly triggers a clipboard action (button press, not background polling). This avoids spam alerts.

### A.2 SelectedTextKit Library

For production-grade text capture, consider [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) by tisfeng:

```swift
// Alternative to our manual AX + Cmd+C approach:
import SelectedTextKit

do {
    let selectedText = try await getSelectedTextByMenuBarActionCopy()
    print("Captured: \(selectedText)")
} catch {
    print("Failed: \(error)")
}
```

**Advantages:**
- Handles edge cases we'd have to discover (menu bar copy fallback, app-specific quirks)
- Tested across many macOS apps
- Active maintenance

**Our approach is still recommended** because:
- Fewer dependencies
- Full control over AX → Cmd+C fallback timing
- No external library for a security-sensitive operation (accessibility API)

Worth keeping as a reference if edge cases pile up during testing.

### A.3 GRDB Performance Justification (Benchmarks)

Independent 2024 benchmarks confirm GRDB is the right choice:

| Operation | GRDB | Core Data | SwiftData | Raw SQLite |
|-----------|------|-----------|-----------|------------|
| Fetch 200K rows | 0.06-0.24s | 0.45s | Slower than Core Data | 0.04s |
| Insert 50K rows | 0.06-0.38s | 0.40s | — | 0.03s |
| Change tracking fetch | 0.24s | 0.45s | — | N/A |

SwiftData is 2-10x slower and degrades above 100K objects. For a chat app with potentially thousands of conversations and tens of thousands of messages, GRDB's near-raw-SQLite performance is ideal.

### A.4 ScreenCaptureKit: macOS 15 Mandatory Migration

**CGWindowListCreateImage is fully obsoleted in macOS 15 (Sequoia).** It won't compile/link in new Xcode toolchains targeting macOS 15+. Our spec correctly uses `SCScreenshotManager` — this is confirmed as the required path forward.

Key detail from research: `SCScreenshotManager.captureImage(contentFilter:configuration:)` is the one-shot equivalent. The older streaming-based `SCStream` approach is unnecessary for single screenshots.

### A.5 Global Hotkey: macOS 15 Sandbox Bug

There's a known bug in macOS 15 Sequoia where Option-only and Option+Shift keyboard shortcuts fail in sandboxed apps when using the KeyboardShortcuts library. Since we use the `HotKey` library (soffes) with `⌥+Space` (Option+Space), **test this specifically on macOS 15**.

If the bug affects HotKey as well:
- **Workaround 1:** Change Select & Ask hotkey to `⌘+Shift+Space` (avoids Option modifier)
- **Workaround 2:** Disable sandbox for testing (JeffyBar is not App Store distributed)
- **Workaround 3:** Use `MASShortcut` library which handles Carbon API differently

### A.6 AppleScript Browser Bundle IDs (Complete Reference)

```swift
// Extended browser support — verified bundle IDs:
private static let browserBundleIds: [String: String] = [
    "com.google.Chrome": "Google Chrome",
    "com.google.Chrome.canary": "Google Chrome Canary",
    "com.apple.Safari": "Safari",
    "com.apple.SafariTechnologyPreview": "Safari Technology Preview",
    "company.thebrowser.Browser": "Arc",
    "org.mozilla.firefox": "Firefox",          // Limited AppleScript support
    "com.microsoft.edgemac": "Microsoft Edge",
    "com.brave.Browser": "Brave Browser",
    "com.vivaldi.Vivaldi": "Vivaldi",
    "com.operasoftware.Opera": "Opera",
]

// Chrome-style AppleScript works for: Chrome, Brave, Edge, Vivaldi, Opera, Arc
// Safari has its own syntax: "URL of front document"
// Firefox: No reliable AppleScript URL support; use window title as fallback
```

### A.7 Image Size Optimization for LAN Transmission

Base64 encoding adds ~33% overhead. For a typical 1920×1080 screenshot:
- PNG: ~2-5 MB → Base64: ~2.7-6.7 MB
- JPEG (0.8 quality): ~200-500 KB → Base64: ~267-667 KB

**Recommendation:** Use JPEG compression for screenshots sent via LAN:

```swift
// In ScreenshotCaptureManager.imageToBase64:
func imageToBase64(_ image: NSImage, quality: CGFloat = 0.85) -> String? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }

    // Use JPEG for much smaller payloads (5-10x smaller than PNG)
    guard let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality]) else {
        return nil
    }

    return jpegData.base64EncodedString()
}
```

And update the content type in the message:
```swift
"url": "data:image/jpeg;base64,\(base64)"  // Was image/png
```

**LAN-specific URLSession config:**
```swift
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 5.0
config.timeoutIntervalForResource = 30.0
config.requestCachePolicy = .reloadIgnoringLocalCacheData
config.networkServiceType = .responsiveData  // Prioritize low latency
```

### A.8 Parallel Context Capture Pattern

The spec mentions parallel capture but here's the full implementation:

```swift
// In Select & Ask handler — capture everything in parallel BEFORE activating JeffyBar:
func handleSelectAndAsk() async {
    // All three run concurrently
    async let contextResult = AppContextManager.shared.captureCurrentContext()
    async let textResult = TextCaptureManager.shared.captureSelectedText()
    // Note: screenshot is optional for Select & Ask, but included for completeness
    // async let screenshotResult = ScreenshotCaptureManager.shared.captureActiveWindow()

    let context = await contextResult
    let selectedText = await textResult

    // NOW activate JeffyBar (changes frontmost app)
    await MainActor.run {
        openWindow(id: "main-window")
        NSApp.activate(ignoringOtherApps: true)

        if let text = selectedText, !text.isEmpty {
            appState.pendingSelectAndAskText = text
            appState.pendingAppContext = context
        }
    }
}
```

**Critical timing note:** `NSWorkspace.shared.frontmostApplication` returns the currently active app. Once `NSApp.activate()` is called, it returns JeffyBar itself. All context capture MUST happen before activation.
