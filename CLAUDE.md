# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Vibe Island** — a macOS menu bar app (Swift 6.0, SwiftUI + AppKit) that monitors AI coding tools (Claude Code, OpenCode, Codex CLI) and displays their status via a "Dynamic Island" style UI positioned at the Mac notch. Includes pixel pet animations, sound notifications, and API quota monitoring widgets.

Platform: macOS 14.0+ (Sonoma). Bundle ID prefix: `com.twmissingu`.

## Build System

The project uses **XcodeGen** — `.xcodeproj` is generated, not hand-maintained (excluded via .gitignore).

```bash
# Generate Xcode project (prerequisite for all Xcode operations)
xcodegen generate

# Build & run in Xcode
open VibeIsland.xcodeproj   # then Cmd+R

# Release build (clean build + DMG)
./scripts/build-release.sh

# First-time dev setup (checks deps, generates project, type-checks CLI)
./scripts/dev-setup.sh
```

## Testing

```bash
# Run all tests (hook format tests + Xcode unit tests)
./scripts/run-tests.sh

# Run only Xcode unit tests
xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests

# Run a single test class
xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests/SessionStateTests

# Run a single test method
xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests/SessionStateTests/testMethodName

# CLI type-check (no Xcode needed)
swiftc -typecheck -target arm64-apple-macosx14.0 Sources/CLI/vibe-island.swift Sources/CLI/HookHandler.swift Sources/CLI/SharedModels.swift
```

Tests use XCTest with `@testable import VibeIsland`. `SessionManager` provides a `makeForTesting()` factory for dependency injection.

## Architecture

**4 build targets** defined in [project.yml](project.yml):

| Target | Type | Description |
|--------|------|-------------|
| **VibeIsland** | macOS App | Main menu bar app with Dynamic Island UI |
| **VibeIslandCLI** | CLI Tool | `vibe-island` binary — hook handler invoked by Claude Code |
| **VibeWidget** | App Extension | macOS Widget for API quota display |
| **LLMQuotaKit** | Framework | Shared library for quota API providers |

Pattern: **MVVM + @Observable**, singletons with `@MainActor`.

### Data Flow

```
Claude Code hook → stdin JSON → vibe-island CLI → HookHandler
  → writes session JSON to ~/.vibe-island/sessions/<pid>.json (flock locking)

SessionFileWatcher (DispatchSource) → detects file changes → SessionManager
OpenCodeMonitor (4-level fallback: plugin hook → SSE → file monitoring → pgrep)
CodexMonitor (process detection via pgrep)
  ↓
MultiToolAggregator (polls every 3s, aggregates all sessions, sorts by priority)
  ↓
DynamicIslandPanel (NSPanel at notch) → IslandView (highest-priority session)
  ↓
SoundManager (audio cues) + PetEngine (pixel pet animations)
```

### Key Source Layout

- **App entry**: `Sources/VibeIsland/App/VibeIslandApp.swift` — creates `DynamicIslandPanel`, calls `StateManager.startMonitoring()`
- **CLI entry**: `Sources/CLI/vibe-island.swift` — `hook <EventType>` reads stdin JSON, delegates to `HookHandler`
- **Services**: `Sources/VibeIsland/Services/` — monitors, watchers, managers
- **Window**: `Sources/VibeIsland/Window/` — `DynamicIslandPanel` (NSPanel positioned at notch), `IslandState`
- **Pet engine**: `Sources/VibeIsland/Pet/` — `PetEngine`, `PetAnimations`, `PetState`
- **Quota providers**: `Packages/LLMQuotaKit/Sources/LLMQuotaKit/Providers/` — `QuotaProvider` protocol + implementations (MiMo, Kimi, Ark, MiniMax, Zai)
- **Shared models (CLI ↔ App)**: `Sources/CLI/SharedModels.swift` — `Session`, `SessionEvent`, `SessionState`, file locking

### Runtime Data

Session files live in `~/.vibe-island/sessions/`. The CLI and app communicate through these JSON files using `flock`-based file locking. App group: `group.com.twmissingu.VibeIsland`.

## Dependencies

- **XcodeGen**: `brew install xcodegen` — required to generate the Xcode project
- No external package dependencies beyond Apple frameworks; `LLMQuotaKit` is a local SPM package
