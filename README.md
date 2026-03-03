# ⚡ JeffyBar

Native macOS menu bar app — the front-end for **Jeff**, an AI assistant powered by [OpenClaw](https://github.com/openclaw/openclaw).

## What Is This?

JeffyBar lives in your macOS menu bar. Press **⌘+J** (or click the ⚡ icon) and Jeff is right there — ask anything, drop files, get rich output in a floating artifact panel.

## Features

### Phase 1 — Core
- **Chat** — streaming responses, markdown rendering
- **Artifacts** — code, documents, HTML, PDFs rendered in a floating panel
- **File handling** — drag and drop files to send, save generated output to Finder
- **Zero-config** — discovers your OpenClaw Gateway automatically via Bonjour
- **System integration** — global hotkey (⌘+J), Siri Shortcuts, launch at login

### Phase 2 — Intelligence & Persistence
- **Model Picker** — switch between Claude Opus, Sonnet, Haiku, GPT 5.3, Gemini 3 Pro. Persists across restarts.
- **Conversation Persistence** — SQLite (via GRDB.swift) stores all conversations, messages, and artifacts. Full sidebar with search.
- **Select & Ask** — global hotkey (⌥+Space) captures selected text from ANY macOS app and sends it to Jeff with app context. Uses Accessibility API with Cmd+C fallback for Electron apps.
- **App Context Detection** — auto-detects frontmost app, window title, and browser URL. Recognises Gmail, GitHub, Google Docs, Notion, Slack, Linear, Figma, Jira, and more.
- **Quick Actions** — contextual action buttons that change per detected app/service (e.g. "Draft Reply" for Gmail, "Review PR" for GitHub).
- **Screenshot Capture** — global hotkey (⌘+⇧+J) captures the active window via ScreenCaptureKit and sends it as a vision message.
- **Clipboard Integration** — read/write clipboard, paste into chat, copy assistant responses.
- **Rich Notifications** — alerts when Jeff replies in background, with Reply/Dismiss actions.
- **Settings Window** — model defaults, context toggles, accessibility & screen recording permission status, Bonjour discovery.

## Architecture

```
Mac Studio (client)              Mac Mini (server)
┌────────────────────┐           ┌──────────────────────┐
│   JeffyBar.app     │   LAN    │  OpenClaw Gateway     │
│   ⚡ Menu Bar      │◄────────►│  WebSocket + HTTP     │
│   Chat + Artifacts │  :18789  │  AI, tools, memory    │
└────────────────────┘           └──────────────────────┘
```

## Hotkeys

| Hotkey | Action |
|--------|--------|
| ⌘+J | Open/focus Jeff |
| ⌥+Space | Select & Ask (capture selection + context) |
| ⌘+⇧+J | Screenshot active window → Jeff |

## Permissions

| Permission | Purpose |
|-----------|---------|
| Accessibility | Text capture from any app (Select & Ask) |
| Screen & System Audio Recording | Screenshot capture |
| Automation | Browser URL extraction (auto-prompted) |
| Notifications | Background reply alerts |
| Local Network | Bonjour gateway discovery |

## Dependencies

| Package | Purpose |
|---------|---------|
| [GRDB.swift](https://github.com/groue/GRDB.swift) | SQLite conversation persistence |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) | Markdown rendering in chat |
| [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) | Secure token storage |
| [HotKey](https://github.com/soffes/HotKey) | Global keyboard shortcuts |

## Requirements

- macOS 14 (Sonoma) or later
- OpenClaw Gateway running on the network
- Xcode 15+ to build

## Build

```bash
# Generate Xcode project from project.yml
brew install xcodegen  # if not installed
xcodegen generate
open JeffyBar.xcodeproj
# ⌘+R to build and run
```

## License

MIT
