# ⚡ JeffyBar

Native macOS menu bar app — the front-end for **Jeff**, an AI assistant powered by [OpenClaw](https://github.com/openclaw/openclaw).

## What Is This?

JeffyBar lives in your macOS menu bar. Press **⌘+J** (or click the ⚡ icon) and Jeff is right there — ask anything, drop files, get rich output in a floating artifact panel.

- **Chat** — streaming responses, markdown rendering, conversation history
- **Artifacts** — code, documents, HTML, PDFs rendered in a floating panel
- **File handling** — drag and drop files to send, save generated output to Finder
- **Zero-config** — discovers your OpenClaw Gateway automatically via Bonjour
- **System integration** — global hotkey, notifications, Siri Shortcuts, launch at login

## Architecture

```
Mac Studio (client)              Mac Mini (server)
┌────────────────────┐           ┌──────────────────────┐
│   JeffyBar.app     │   LAN    │  OpenClaw Gateway     │
│   ⚡ Menu Bar      │◄────────►│  WebSocket + HTTP     │
│   Chat + Artifacts │  :18789  │  AI, tools, memory    │
└────────────────────┘           └──────────────────────┘
```

## Requirements

- macOS 14 (Sonoma) or later
- OpenClaw Gateway running on the network
- Xcode 15+ to build

## Build

```bash
open JeffyBar.xcodeproj
# ⌘+R to build and run
```

## License

MIT
