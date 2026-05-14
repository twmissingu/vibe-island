[![English](https://img.shields.io/badge/English-blue.svg)](README.md)
[![中文](https://img.shields.io/badge/中文-red.svg)](README_zh.md)

---

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0+-blue?logo=apple" alt="macOS 14.0+" />
  <img src="https://img.shields.io/badge/Swift-6.0-orange?logo=swift" alt="Swift 6.0" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="MIT License" />
  <img src="https://img.shields.io/badge/Platform-x86_64%20%7C%20arm64-lightgrey" alt="Platform" />
</p>

<h1 align="center">VibeIsland</h1>
<p align="center"><em>A Dynamic Island for your LLM coding sessions — monitor Claude Code &amp; OpenCode right from your menu bar.</em></p>

<p align="center">
  <img src="https://img.shields.io/badge/Claude%20Code-F9A03C?logo=claude&logoColor=white" />
  <img src="https://img.shields.io/badge/OpenCode-000000?logo=openai&logoColor=white" />
  <img src="https://img.shields.io/badge/Status-Active-success" />
</p>

---

## Why VibeIsland?

Coding with AI agents is powerful, but you're flying blind. How much context is left? Is Claude waiting for your permission? Did the last tool call fail? VibeIsland brings that information to your menu bar — no alt-tabbing, no terminal peeking.

VibeIsland transforms your macOS menu bar into a live dashboard for all your LLM coding sessions, wrapped in a playful Dynamic Island experience with a pixel pet companion.

## Features

- **Live Session Monitoring** — Real-time status for Claude Code and OpenCode sessions: thinking, coding, waiting, permission requests, errors, and compaction
- **Context Usage Tracking** — Progress bar showing how much of the 200K context window is consumed, with input/output/reasoning token breakdown
- **Multi-Session Management** — Auto mode shows the highest-priority session; manual mode lets you pin one session
- **Pixel Pet Companion** — 8 pet types × 5 evolution tiers × 8 animations that react to your coding state
- **Two Themes** — Pixel Dark (retro game aesthetic) and Glass Transparent (modern frosted glass)
- **CLI Hook Integration** — `vibe-island` CLI tool processes Claude Code hooks and writes session files via flock-locked IPC
- **Context Compaction Alerts** — Visual indicator when Claude Code compresses its context
- **Sound Notifications** — Optional state-change sounds when your session transitions between states

## Quick Start

### Prerequisites

- macOS 14.0+ (Sonoma)
- Claude Code and/or OpenCode (optional, for session tracking)

### Installation

#### Download (pre-built)

```bash
# One-line install (recommended)
curl -fsSL https://raw.githubusercontent.com/twmissingu/vibe-island/main/scripts/install.sh | bash

# Or manual: download VibeIsland-<arch>.tar.gz from Releases page
tar xzf VibeIsland-*.tar.gz
cp -r VibeIsland.app /Applications/
xattr -cr /Applications/VibeIsland.app
open /Applications/VibeIsland.app
```

#### Build from source

```bash
git clone https://github.com/twzhan/vibe-island.git
cd vibe-island
./scripts/dev-setup.sh     # checks deps, generates project, type-checks CLI
xcodegen generate           # generates .xcodeproj from project.yml
```

Then open `VibeIsland.xcodeproj` in Xcode and build the `VibeIsland` scheme.

### Usage

1. **Launch the app** — VibeIsland runs as a menu bar agent (LSUIElement). You'll see a Dynamic Island icon in your menu bar.
2. **Start coding** — Use Claude Code or OpenCode normally. Session states appear in real-time.
3. **Click the island** — Expand to see session details: context usage, token counts, tool usage stats, and your pixel pet.
4. **Install hooks (Claude Code)**:
   ```bash
   ./scripts/dev-setup.sh
   # or manually:
   vibe-island hook install
   ```

## For AI Agents

VibeIsland is designed for seamless AI agent interaction:

1. **Clone and install dependencies**
   ```bash
   git clone https://github.com/twzhan/vibe-island.git
   cd vibe-island
   brew install xcodegen
   xcodegen generate
   ```

2. **Build**
   ```bash
   xcodebuild build -scheme VibeIsland -destination 'platform=macOS'
   # or build the CLI only
   cd Sources/CLI && swiftc -typecheck -target arm64-apple-macosx14.0 *.swift
   ```

3. **Run tests**
   ```bash
   ./scripts/run-tests.sh
   ```

4. **Project structure**
   - `Sources/VibeIsland/` — macOS app (SwiftUI, MVVM, @Observable)
   - `Sources/CLI/` — CLI tool for hook integration
   - `Packages/LLMQuotaKit/` — Local SPM framework for LLM quota providers
   - `Tests/` — Unit tests (XCTest) + standalone script tests
   - `project.yml` — XcodeGen project spec (DO NOT edit .xcodeproj directly)

5. **Key conventions**
   - All `project.yml` changes require `xcodegen generate`
   - Session file I/O must use `flock` locking (no `.atomic` writes)
   - CLI and App share duplicated model types in `Sources/CLI/SharedModels.swift` and `Sources/VibeIsland/Models/` — keep in sync
   - `SessionState.transition()` and `isBlinking` must be identical in both copies

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Menu Bar Agent                  │
│  ┌───────────────────────────────────────────┐  │
│  │         DynamicIslandPanel                 │  │
│  │  [Compact] ◄─click► [ExpandedIslandView]  │  │
│  │         SessionManager                     │  │
│  └───────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────┘
                       │ IPC: flock-locked JSON files
┌──────────────────────▼──────────────────────────┐
│  ~/.vibe-island/sessions/<pid>.json              │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│  CLI (Sources/CLI/)    │  OpenCode Monitor       │
│  HookHandler.swift     │  ContextMonitor.swift   │
│  (reads stdin events)  │  (reads SQLite DB)      │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│  Claude Code           │  OpenCode               │
│  (hook events via      │  (SQLite DB polling)    │
│   transcript JSONL)    │                         │
└─────────────────────────────────────────────────┘
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
