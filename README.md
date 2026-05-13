# Vibe Island

> Your AI coding partner lives in the notch — monitoring sessions, tracking context, cheering you on with pixel pets.

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/sonoma/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## Why Vibe Island?

When coding with AI tools like Claude Code and OpenCode, critical information gets buried:

- **Which sessions are active?** — You have 3 terminals open, 2 VS Code windows — which ones are doing work?
- **How much context is left?** — AI context windows fill up silently. When you hit the limit, work gets lost.
- **When does AI need you?** — Permission requests, errors, completions — without notifications, you miss them.

**Vibe Island** places a Dynamic Island-style monitor in your MacBook's notch. At a glance: active sessions, context usage, tool counts, and a pixel pet that reacts to everything.

---

## Features

- 🏝️ **Dynamic Island UI** — Sits in the macOS notch. Compact when idle, expands on click with 3 tabs: sessions, context usage, and daily stats.
- 📊 **Session Monitoring** — Tracks Claude Code and OpenCode sessions in real time. Shows tool usage counts, context percentage, and active subagents.
- 🐱 **Pixel Pets** — 8 pets × 5 skin tiers. Unlock by coding. Each pet reacts to your AI's state — shakes on errors, celebrates on completion, glows on compression.
- 🎯 **Daily Stats** — Today's coding time, top tools ranked by usage, daily goal progress. All in the expanded panel.
- 🔊 **Smart Notifications** — Sound alerts only for critical events (permission requests, errors). Cooldown prevents notification fatigue.
- 🎨 **Two Themes** — Pixel Dark (geeky, monospaced, ASCII dividers) and Glass Transparent (vibrant blur, session-colored glow).
- 🛠️ **Multi-Tool Support** — Claude Code and OpenCode, side by side.

---

## For Users

### System Requirements

- **macOS 14.0+** (Sonoma)
- Apple Silicon (M1/M2/M3/M4) or Intel Mac with a notch (recommended) or standard menu bar
- Claude Code and/or OpenCode (optional — Vibe Island works as a standalone pet island too)

### Quick Start

#### 1. Download & Install

1. Go to [GitHub Releases](https://github.com/twzhan/vibe-island/releases) and download `VibeIsland.dmg`.
2. Double-click the DMG, then **drag VibeIsland.app to Applications**.
3. First launch? macOS Gatekeeper may show:
   > **"VibeIsland.app" cannot be opened because the developer cannot be verified.**
   
   Right-click → **Open** → click **"Open"**. Run once, and it'll work normally after.

#### 2. First Launch

Launch Vibe Island. You'll see `( ^_^ )` in your notch — a pixel pet sleeping. Click it to expand.

**If Claude Code or OpenCode is running**, Vibe Island detects it and prompts you to install the hook/plugin right in the panel — no settings hunting.

**If no AI tools are detected**, Vibe Island shows a welcome card with instructions. Or just keep it open — the pet is cute.

#### 3. Configure Hooks (for real-time session data)

Click the gear icon in the expanded panel → **Plugin** section:
- **Claude Code**: Click "Install" next to Claude Code → authorize `~/.claude` access
- **OpenCode**: Click "Install" next to OpenCode

That's it. Session data appears in the island immediately.

### Debugging

```bash
VIBE_ISLAND_DEBUG=1 open /Applications/VibeIsland.app
# Logs → ~/.vibe-island/hook-debug.log
```

---

## For Developers

### Prerequisites

- macOS 14.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Claude Code / OpenCode (optional, for testing hook integration)

### Build

```bash
git clone https://github.com/twzhan/vibe-island.git
cd vibe-island

# First-time setup (checks deps, generates Xcode project, type-checks CLI)
./scripts/dev-setup.sh

# Generate Xcode project (required after any change to project.yml)
xcodegen generate
open VibeIsland.xcodeproj
# Press Cmd+R
```

### Build Release DMG

```bash
./scripts/build-release.sh
# Output: build/VibeIsland.dmg
```

### Run Tests

```bash
./scripts/run-tests.sh
```

### CLI Typecheck (no Xcode needed)

```bash
cd Sources/CLI && swiftc -typecheck -target arm64-apple-macosx14.0 \
  vibe-island.swift HookHandler.swift SharedModels.swift
```

### Project Structure

```
Sources/VibeIsland/      — Main app (SwiftUI + AppKit)
Sources/CLI/             — CLI tool (hook integration, session file writer)
Packages/LLMQuotaKit/    — LLM quota monitoring framework
project.yml              — XcodeGen project spec
scripts/                 — Build, release, and setup scripts
Tests/                   — Unit + UI tests
```

---

## For AI Agents

This project is designed for seamless AI agent interaction:

1. **Clone & setup**
   ```bash
   git clone https://github.com/twzhan/vibe-island.git
   cd vibe-island
   brew install xcodegen
   ./scripts/dev-setup.sh
   ```

2. **Key files to understand**
   - `Sources/VibeIsland/App/VibeIslandApp.swift` — App entry point, panel creation
   - `Sources/CLI/vibe-island.swift` — CLI entry point, `hook <EventType>` stdin JSON handler
   - `Sources/CLI/SharedModels.swift` — Session/SessionEvent/SessionState models (duplicated in App target)
   - `Sources/VibeIsland/Views/IslandView.swift` — Main Dynamic Island UI (compact + expanded)

3. **Conventions**
   - Swift 6 strict concurrency, all singletons `@MainActor`
   - MVVM + `@Observable`, dependency injection via `.environment`
   - All session file I/O uses `flock` locking
   - JSON writes never use `.atomic` (changes inode, breaks DispatchSource)
   - CLI and App models are duplicated — `SessionState.transition()` and `isBlinking` must stay in sync

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     macOS Menu Bar (Notch)                    │
├──────────────────────────────────────────────────────────────┤
│  ┌──────┐  ┌──────────────┐         ┌──────┐               │
│  │  (   │  │  🐱 42%      │         │   )  │               │
│  │ state│  │  context      │  notch  │ state│               │
│  └──────┘  └──────────────┘         └──────┘               │
└──────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
  ┌─────────────┐              ┌──────────────┐
  │ Claude Code │              │   OpenCode   │
  │   (hook)    │              │  (plugin)    │
  └──────┬──────┘              └──────┬───────┘
         │                            │
         └──────────┬─────────────────┘
                    ▼
           ┌────────────────┐
           │  SessionManager │  ← aggregates all sessions
           │  + FileWatcher  │  ← DispatchSource on JSON files
           └────────┬───────┘
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
  ┌────────────┐       ┌──────────────┐
  │ IslandView │       │ ExpandedPanel │
  │ (compact)  │       │ 3 tabs + pet  │
  └────────────┘       └──────────────┘
```

**Data flow:** Claude Code hook writes JSON → CLI writes `~/.vibe-island/sessions/<pid>.json` → `SessionFileWatcher` (DispatchSource) detects changes → `SessionManager` updates → `IslandView` re-renders.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines. All contributions welcome — bug fixes, features, pixel art, sound effects.

- Fork → feature branch → PR
- `xcodegen generate` after project.yml changes
- Run tests with `./scripts/run-tests.sh`
- Keep CLI ↔ App models in sync

---

## License

MIT © 2026 twzhan — see [LICENSE](LICENSE)

## Acknowledgments

- Inspired by Apple's Dynamic Island design
- Built with SwiftUI + AppKit
- 16×16 pixel art by the project contributors
