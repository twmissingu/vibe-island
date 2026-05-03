[![English](https://img.shields.io/badge/English-blue.svg)](README.md)
[![中文](https://img.shields.io/badge/中文-red.svg)](README_zh.md)
[![Platform](https://img.shields.io/badge/platform-macOS%2014.0+-blue.svg)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

# Vibe Island

> Your AI coding sessions, brought to life — Dynamic Island UI, pixel pet companions, sound notifications, and context awareness, all in one macOS menu bar app.

Vibe Island monitors multiple AI coding tools (Claude Code, OpenCode, Codex CLI) in real time and surfaces session status in a Dynamic Island-style overlay pinned to the macOS notch area. Think of it as **Dynamic Island for developers**.

## Features

### Multi-Tool Session Monitoring

- **Claude Code** — Native hook integration with 14 event types, zero-config setup
- **OpenCode** — JavaScript plugin with 4-level fallback detection (Plugin → SSE → File → Process)
- **Codex CLI** — Process-level detection via `pgrep`

### Dynamic Island UI

- Compact mode: single-line status pinned to the screen notch
- Expanded mode: full session details with context usage, tool stats, and sub-agent tracking
- State-driven colors and animations (thinking, coding, waiting, error, compacting)
- Multi-session tracking with manual/auto pin modes

### Context Awareness

- Real-time context window usage tracking (tokens used / total / remaining)
- Input / output / reasoning token breakdown
- Per-session tool and skill usage stats
- Warning notifications at 80% and 95% context thresholds

### Pixel Pet System

- 8 pet companions: Cat, Dog, Rabbit, Fox, Penguin, Robot, Ghost, Dragon
- 5 skin tiers unlocked by coding time: Basic → Glow → Metal → Neon → King
- 8 animation states synced to AI tool status
- 16x16 pixel art with hex color codes

### Sound Notifications

- Configurable audio cues for session state changes
- Per-event volume control and test buttons

### LLM Quota Tracking

- 5 providers: Xiaomi MiMo, Kimi, MiniMax, ZhiPu Z.AI, Volcengine Ark
- macOS Widget for real-time quota display

### Gamification

- Achievement system with 5 categories and rarity tiers (common → legendary)
- Leaderboards: daily, weekly, monthly, all-time rankings
- XP progression linked to coding time and tool usage

## Quick Start

### Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Installation

```bash
git clone https://github.com/anthropics/vibe-island.git
cd vibe-island
./scripts/dev-setup.sh
```

Press **Cmd+R** in Xcode to build and run.

### Claude Code Integration

Hooks are auto-installed on first launch. For manual setup:

```bash
vibe-island hook SessionStart
vibe-island hook PreToolUse
vibe-island hook PostToolUse
vibe-island hook Stop
```

### OpenCode Integration

```bash
./scripts/install-opencode-plugin.sh
```

### Build a Release

```bash
./scripts/build-release.sh
```

## For AI Agents

```bash
# Clone and setup
git clone https://github.com/anthropics/vibe-island.git
cd vibe-island
./scripts/dev-setup.sh

# Build
xcodegen generate
xcodebuild build -scheme VibeIsland -destination 'platform=macOS'

# Test (CLI type-check)
cd Sources/CLI && swiftc -typecheck -target arm64-apple-macosx14.0 \
  vibe-island.swift HookHandler.swift SharedModels.swift

# Project structure
# - Edit project.yml then xcodegen generate for structural changes
# - Never edit .xcodeproj directly (generated, gitignored)
# - CLI and app share models via Sources/CLI/SharedModels.swift
```

## Architecture

```
Claude Code hook → stdin JSON → vibe-island CLI → HookHandler
  → writes session JSON to ~/.vibe-island/sessions/<pid>.json

SessionFileWatcher (DispatchSource) → detects file changes → SessionManager
OpenCodeMonitor (plugin hook → SSE → file monitoring → pgrep)
CodexMonitor (process detection)
  ↓
SessionManager (unified session store, sorted by lastActivity)
  ↓
DynamicIslandPanel (NSPanel at notch) → IslandView
  ↓
SoundManager (audio cues) + PetEngine (pixel pet animations)
```

## State Priority

```
Approval > Error > Compression > Coding > Thinking > Waiting > Completed > Idle
```

Session list sorting uses `lastActivity` descending (most recently active first). State priority is used only for `aggregateState` computation.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Edit `project.yml` if adding new files, then `xcodegen generate`
4. Submit a pull request

See [CLAUDE.md](CLAUDE.md) for detailed development conventions.

## License

MIT License - see [LICENSE](LICENSE) for details.
