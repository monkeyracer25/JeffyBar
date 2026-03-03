# JeffyBar — Phase 2 Specification

## Status: Phase 1 Complete ✅
- Menu bar app with ⚡ icon
- Chat popover + full window (⌘+J)
- HTTP+SSE streaming to OpenClaw gateway
- Artifact panel (floating NSPanel) — auto-opens for code/HTML
- Code fences hidden from chat, clean button UI (Claude Desktop style)
- Bonjour discovery
- Gateway: http://192.168.1.131:18789

## Phase 2 — Claude Desktop Parity

### 2.1 Model Picker
- Dropdown in chat input area to select model
- Options: Opus 4.6, Sonnet 4.6, Haiku 4.5, GPT 5.3, Gemini 3 Pro
- Sends selected model in `model` field of chat completions request
- Remember last-used model in UserDefaults

### 2.2 New Session / Reset
- "New Chat" button (⌘+N) — clears conversation history
- Doesn't need to reset server-side (stateless requests)
- Optional: conversation list sidebar (like Claude Desktop)

### 2.3 Chat Memory / History
- Persist conversations locally (Core Data or JSON files)
- Sidebar with conversation list
- Click to load previous conversation
- Auto-title conversations based on first message

### 2.4 Settings Window (Proper)
- Standalone NSWindow (not sheet on popover) ✅ already done
- Gateway URL + token
- Default model selection
- Appearance (light/dark/system)
- Launch at login toggle
- Global hotkey config

### 2.5 Copy / Actions on Messages
- Copy button on hover for each message
- Regenerate last response
- Edit and resend user message

### 2.6 Streaming Improvements  
- Smooth token-by-token rendering
- Stop button mid-stream
- Typing indicator

## Phase 3 — Screen Context Awareness

### 3.1 Active App Detection
- Monitor frontmost application via NSWorkspace
- Send app name + window title as context with each message
- "Help me with this" knows you're in Excel/Chrome/etc.

### 3.2 Screenshot Capture (⌘+Shift+J)
- Capture active window via CGWindowListCreateImage
- Send as base64 image in message
- Jeff sees what you're looking at

### 3.3 Clipboard Integration
- Monitor NSPasteboard for changes
- "What's in my clipboard" → Jeff can read it
- Auto-paste Jeff's output to clipboard

### 3.4 App-Specific Prompts
- When Excel is frontmost → "Analyze this spreadsheet"
- When Chrome is frontmost → "Summarize this page"
- When Finder is frontmost → "What files are here?"
- Configurable per-app quick actions

### 3.5 Cross-Machine Architecture
JeffyBar runs on Studio, Jeff runs on Mini.
- Screenshots captured on Studio → sent to Jeff via HTTP
- File operations happen on Mini → results sent back
- Clipboard is local to Studio
- App detection is local to Studio
- All context sent as part of the chat message

### Research Needed (Risa's Oracle Bar spec)
- How does Oracle Bar handle app awareness?
- Does it use Accessibility APIs or just NSWorkspace?
- Can it read window content (not just title)?
- What's the UX for contextual actions?

## Phase 4 — Deep Integration
- File drag-and-drop with content reading
- Apple Shortcuts / Intents
- Notification center integration
- Voice input (Speech framework)
- Multi-conversation tabs
- Tailscale for remote access

## Architecture Notes
- Chat completions endpoint is STATELESS (no user field)
- Instruction appended to every user message for inline content
- No agent header — uses default main agent
- Gateway token hardcoded as fallback default
- Bundle ID: com.jeffybar.JeffyBar
