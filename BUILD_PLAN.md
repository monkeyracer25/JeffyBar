# JeffyBar — Build Plan

## What Is This?
A native macOS Swift/SwiftUI menu bar app — the front-end for **Jeff**, Jonny's AI assistant running on OpenClaw (Mac mini). Used from the Mac Studio over LAN.

This is NOT a generic AI chat app. It's Jeff's face on macOS.

---

## Architecture

```
Mac Studio (daily driver)          Mac Mini (always-on server)
┌──────────────────────┐           ┌──────────────────────────┐
│    JeffyBar.app      │           │   OpenClaw Gateway       │
│                      │           │                          │
│  ⚡ Menu Bar Icon    │   LAN     │  • WebSocket protocol    │
│  ⌘+J Global Hotkey  │◄─────────►│  • HTTP /v1/chat/comp    │
│  Chat Popover       │   :18789  │  • SSE streaming         │
│  Full Window        │           │  • Tools, memory, cron   │
│  Artifact Panel     │           │  • Sub-agents, sessions  │
│  File Drop Zone     │           │  • Bonjour advertising   │
└──────────────────────┘           └──────────────────────────┘
```

## Build Chain

```
Jeff (coordinator) → specs the work, reviews output, delivers to Jonny
    └── Kodi (coding orchestrator) → manages coding agents, monitors quality
            └── Claude Code (coder) → does ALL the actual Swift/Xcode work
```

**Kodi never writes code.** He crafts prompts, launches Claude Code, reviews its output, course-corrects.

---

## Tech Stack

| Component | Choice | Why |
|-----------|--------|-----|
| **Language** | Swift 5.9+ | Native macOS |
| **UI** | SwiftUI (macOS 14+) | Modern, declarative |
| **Menu Bar** | `MenuBarExtra(.window)` | Native popover |
| **Artifact Panel** | `NSPanel` (floating) | Stays above, doesn't steal focus |
| **Rich Content** | `WKWebView` in panel | HTML/interactive artifacts |
| **Markdown** | `swift-markdown-ui` | Native SwiftUI rendering |
| **Code Highlighting** | `Highlightr` | Syntax highlighting |
| **Global Hotkey** | `HotKey` (soffes) | ⌘+J system-wide |
| **SSE Client** | `EventSource` (Recouse) | Async/await SSE streaming |
| **Keychain** | `KeychainAccess` | Secure token storage |
| **Discovery** | `NWBrowser` (Network.framework) | Bonjour `_openclaw-gw._tcp` |
| **Min Target** | macOS 14 (Sonoma) | Both machines run 15+ |

### Swift Package Dependencies
```
https://github.com/gonzalezreal/swift-markdown-ui  — MarkdownUI
https://github.com/soffes/HotKey                   — Global hotkeys
https://github.com/Recouse/EventSource              — SSE streaming
https://github.com/nicklama/Highlightr              — Code highlighting
https://github.com/kishikawakatsumi/KeychainAccess  — Keychain
```

---

## Project Structure

```
JeffyBar/
├── JeffyBar.xcodeproj
├── JeffyBar/
│   ├── JeffyBarApp.swift              # @main, MenuBarExtra + WindowGroup
│   ├── Info.plist                     # LSUIElement=YES, Bonjour
│   │
│   ├── Client/                        # OpenClaw communication
│   │   ├── OpenClawClient.swift       # Unified client (orchestrates WS + HTTP)
│   │   ├── GatewayHTTPClient.swift    # HTTP + SSE streaming
│   │   ├── GatewayWSClient.swift      # Full WebSocket protocol (Phase 2)
│   │   ├── BonjourDiscovery.swift     # NWBrowser for gateway discovery
│   │   └── Models/
│   │       ├── ChatMessage.swift
│   │       ├── Artifact.swift
│   │       ├── GatewayProtocol.swift
│   │       └── Session.swift
│   │
│   ├── Views/
│   │   ├── Chat/
│   │   │   ├── ChatPopoverView.swift  # Compact chat (menu bar popover)
│   │   │   ├── ChatView.swift         # Full chat (main window)
│   │   │   ├── MessageBubble.swift    # Message rendering w/ markdown
│   │   │   ├── ChatInputView.swift    # Text input + file drop + send
│   │   │   └── StreamingIndicator.swift
│   │   │
│   │   ├── Artifact/
│   │   │   ├── ArtifactPanel.swift        # NSPanel subclass (floating)
│   │   │   ├── ArtifactPanelView.swift    # Content router
│   │   │   ├── MarkdownArtifactView.swift # Native markdown
│   │   │   ├── HTMLArtifactView.swift     # WKWebView wrapper
│   │   │   ├── CodeArtifactView.swift     # Syntax highlighted
│   │   │   └── PDFArtifactView.swift      # PDFKit
│   │   │
│   │   ├── MainWindowView.swift       # Split: chat + artifact sidebar
│   │   ├── SettingsView.swift         # Connection, appearance, hotkey
│   │   └── ConnectionSetupView.swift  # Bonjour list + manual config
│   │
│   ├── Services/
│   │   ├── HotKeyManager.swift        # ⌘+J registration
│   │   ├── NotificationManager.swift  # Background response alerts
│   │   ├── FileOutputManager.swift    # Save/reveal generated files
│   │   └── WindowManager.swift        # Panel + window lifecycle
│   │
│   ├── Intents/                       # Shortcuts integration
│   │   ├── AskJeffIntent.swift
│   │   └── JeffShortcuts.swift
│   │
│   └── Resources/
│       └── Assets.xcassets            # App icon (⚡), menu bar icons
│
├── BUILD_PLAN.md                      # This file
├── SPEC.md                            # Detailed specification
└── README.md
```

---

## Phased Build Plan

### Phase 1 — Foundation (MVP)
**Goal:** Menu bar icon → click → chat popover → type message → get streaming response from Jeff.

| # | Task | Detail |
|---|------|--------|
| 1.1 | Xcode project setup | macOS 14+ target, SwiftUI lifecycle, SPM deps |
| 1.2 | `MenuBarExtra` popover | `.window` style, ⚡ icon, LSUIElement=YES |
| 1.3 | Chat UI | `ChatPopoverView` with message list + input field |
| 1.4 | HTTP+SSE client | `GatewayHTTPClient` hitting `/v1/chat/completions` with streaming |
| 1.5 | Markdown rendering | `MarkdownUI` for response rendering |
| 1.6 | Settings | Manual gateway URL + auth token input, stored in Keychain |
| 1.7 | Connection indicator | Menu bar icon changes colour based on connection state |

**Deliverable:** Working menu bar chat that talks to Jeff over LAN.

---

### Phase 2 — Full Protocol + Main Window
**Goal:** WebSocket protocol, detachable full window, conversation history, abort.

| # | Task | Detail |
|---|------|--------|
| 2.1 | `GatewayWSClient` | Full WS handshake, auth, reconnection |
| 2.2 | `chat.send` / `chat.history` / `chat.abort` | Core chat methods over WS |
| 2.3 | Main window (`WindowGroup`) | Full-size chat window, launched from popover |
| 2.4 | Conversation history | Load via `chat.history`, persist locally |
| 2.5 | Auto-scroll + streaming UX | Smooth auto-scroll during streaming, typing indicator |
| 2.6 | Abort button | Stop mid-response via `chat.abort` |

**Deliverable:** Full bidirectional WS connection with proper chat UX.

---

### Phase 3 — Artifact Panel
**Goal:** When Jeff generates documents/code/content, it appears in a floating panel.

| # | Task | Detail |
|---|------|--------|
| 3.1 | `NSPanel` floating window | Non-activating, stays above, draggable/resizable |
| 3.2 | Artifact detection | Parse response for code blocks, HTML, file output markers |
| 3.3 | Markdown artifacts | Full markdown render with `MarkdownUI` |
| 3.4 | Code artifacts | Syntax highlighting via `Highlightr`, copy button |
| 3.5 | HTML artifacts | `WKWebView` for rich/interactive content |
| 3.6 | PDF/image preview | PDFKit + native image rendering |
| 3.7 | Save/Reveal actions | Save to `~/Documents/Jeff/`, Reveal in Finder |

**Deliverable:** Rich output panel for anything Jeff generates.

---

### Phase 4 — Polish & Integration
**Goal:** System integration, discovery, file handling, notifications.

| # | Task | Detail |
|---|------|--------|
| 4.1 | Global hotkey (⌘+J) | `HotKey` package, configurable in settings |
| 4.2 | Bonjour discovery | `NWBrowser` for `_openclaw-gw._tcp`, auto-connect |
| 4.3 | File drag-and-drop | Drop files onto chat to send to Jeff |
| 4.4 | Notifications | Alert when Jeff responds while app isn't focused |
| 4.5 | Launch at login | `SMAppService` / Login Items |
| 4.6 | App Intents | Siri Shortcuts: "Ask Jeff..." |
| 4.7 | Menu bar icon animation | Pulse/spin while Jeff is thinking |

**Deliverable:** Polished, integrated macOS citizen.

---

### Phase 5 — Advanced (Future)
- Tailscale discovery for remote access
- Voice input (Speech framework)
- Multi-session/agent switching
- Conversation search
- Custom themes
- Touch Bar support (if applicable)
- Animated ⚡ icon

---

## Gateway Config (Mac Mini)

OpenClaw needs these settings to accept LAN connections:

```yaml
# Bind to LAN (not just loopback)
gateway:
  host: "0.0.0.0"    # or specific LAN IP
  port: 18789

# Enable OpenAI-compatible HTTP endpoint
chatCompletions:
  enabled: true

# Bonjour advertising (likely already on)
bonjour:
  enabled: true
```

Auth token for JeffyBar stored in Keychain on both machines.

---

## Key Design Decisions

1. **HTTP+SSE first, WebSocket second** — faster to MVP, WS adds power later
2. **Menu bar popover for quick, full window for extended** — natural macOS pattern
3. **Floating NSPanel for artifacts** — doesn't steal focus, always accessible
4. **Native markdown, WKWebView only for rich HTML** — keeps it feeling like a Mac app
5. **This is Jeff, not a generic AI app** — no model pickers, no system prompt editors, ⚡ branding throughout
6. **Bonjour for zero-config LAN discovery** — plug and play between machines

---

## OpenClaw API Reference Docs

Essential reading for implementation:
- `openclaw/docs/gateway/protocol.md` — WebSocket protocol
- `openclaw/docs/gateway/openai-http-api.md` — HTTP Chat Completions
- `openclaw/docs/gateway/bonjour.md` — Bonjour discovery
- `openclaw/docs/gateway/discovery.md` — Discovery & transports
- `openclaw/docs/platforms/mac/webchat.md` — Existing WebChat reference
- `openclaw/docs/platforms/mac/canvas.md` — Canvas panel reference
