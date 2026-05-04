# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Vibe Island** — macOS menu bar app (Swift 6.0, SwiftUI + AppKit) monitoring AI coding tools (Claude Code, OpenCode, Codex CLI) with "Dynamic Island" notch UI, pixel pet animations, sound notifications, and API quota widgets.

Platform: macOS 14.0+ (Sonoma). Bundle ID prefix: `com.twmissingu`. App group: `group.com.twmissingu.VibeIsland`.

## Build System

**XcodeGen** — `.xcodeproj` is generated (gitignored). **NEVER edit .xcodeproj manually.**

```bash
xcodegen generate                  # after ANY change to project.yml
open VibeIsland.xcodeproj          # then Cmd+R
./scripts/dev-setup.sh             # first-time setup (checks deps, generates project, type-checks CLI)
./scripts/build-release.sh         # clean Release build + DMG
```

## Testing

```bash
./scripts/run-tests.sh             # all tests (standalone scripts + Xcode unit tests)

# Xcode unit tests
xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests
xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests/TestClass/testMethodName

# CLI type-check (no Xcode needed)
cd Sources/CLI && swiftc -typecheck -target arm64-apple-macosx14.0 vibe-island.swift HookHandler.swift SharedModels.swift
```

### Testing Quirks

- `run-tests.sh` runs `hook_format_test.swift` as a **standalone Swift script** (`swift Tests/.../hook_format_test.swift`) **before** xcodebuild — NOT an XCTest
- `hook_format_test.swift` and `dispatch_source_test.swift` are **excluded** from Xcode test target in `project.yml`
- Tests use `@testable import VibeIsland`; create instances via `SessionManager.makeForTesting()`

## Build Targets

| Target | Type | Key Info |
|--------|------|----------|
| **VibeIsland** | macOS App | Menu bar agent (LSUIElement=true), depends on LLMQuotaKit |
| **VibeIslandCLI** | CLI Tool | Product name `vibe-island`; invoked by Claude Code hooks via stdin JSON |
| **LLMQuotaKit** | Framework | Local SPM package at `Packages/LLMQuotaKit/` |
| **VibeWidget** | App Extension | **Disabled** — commented out in project.yml |

## Architecture

Pattern: **MVVM + @Observable**, singletons with `@MainActor`. Swift 6 strict concurrency.

### Data Flow

```
Claude Code hook → stdin JSON → vibe-island CLI → HookHandler
  → transcript JSONL 增量解析: token 用量 + skill 调用 (<command-name> 标签)
  → PreToolUse 事件: 工具调用计数累加
  → 写入 session JSON: ~/.vibe-island/sessions/<pid>.json (flock locking)

OpenCodeMonitor → 写入 session JSON (plugin hook / SSE / file monitoring / pgrep)
CodexMonitor → 检测进程 (pgrep)
  ↓
SessionFileWatcher (DispatchSource) → 检测文件变化 → SessionManager
  → Session 模型是单一数据源，UI 直接读取
  → OpenCode 会话: 若无 context_usage，从 SQLite DB 补充
  ↓
DynamicIslandPanel (NSPanel at notch) → IslandView
  → ContextUsageCard (有上下文数据) / OpenCodeNoContextCard (等待态)
  ↓
SoundManager (audio cues) + PetEngine (pixel pet animations)
```

#### 上下文数据来源

| 来源 | 数据 | 路径 |
|------|------|------|
| transcript JSONL | token 用量、skill 调用 | CLI `parseTranscriptContext` → Session 文件 |
| PreToolUse hook | 工具调用计数 | CLI `updateToolUsage` → Session 文件 |
| OpenCode SQLite | token 用量、压缩检测 | App `ContextMonitor.fetchContextUsageFromOpenCodeDB` → Session 模型 |

**设计原则**: Session 模型是单一数据源。UI（`ExpandedIslandView`）直接从 Session 构建 `ContextUsageSnapshot`，不经过 ContextMonitor 中转。ContextMonitor 仅负责 OpenCode SQLite 读取和压缩事件检测。

### State Priority

`Approval > Error > Compression > Coding > Thinking > Waiting > Completed > Idle`

Attention-needed states (approval, compression) blink; others are constant color.

**Session list sorting**: `sortedSessions` 按 `lastActivity` 降序排列（最近活跃在前），这是设计意图——用户最关心的是最近正在使用的会话。状态优先级（`SessionState.priority`）仅用于 `aggregateState` 聚合计算。

### Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Add LLM quota provider | `Packages/LLMQuotaKit/Sources/LLMQuotaKit/Providers/` | Implement `QuotaProvider` protocol; add case to `ProviderType` in `Models/` |
| Modify session tracking | `Sources/VibeIsland/Services/` | SessionManager |
| Change Dynamic Island UI | `Sources/VibeIsland/Views/` + `Sources/VibeIsland/Window/` | IslandView + DynamicIslandPanel |
| Add pixel pet animation | `Sources/VibeIsland/Pet/` | PetAnimations (16x16 pixel art with hex colors), PetEngine |
| Modify CLI hook handling | `Sources/CLI/` | vibe-island.swift + HookHandler + SharedModels (shared with app) |
| Change project structure | `project.yml` | Then `xcodegen generate` |

### Key Source Layout

- **App entry**: `Sources/VibeIsland/App/VibeIslandApp.swift` — creates `DynamicIslandPanel`, calls `StateManager.startMonitoring()`
- **CLI entry**: `Sources/CLI/vibe-island.swift` — `hook <EventType>` reads stdin JSON, delegates to `HookHandler`
- **Shared models (CLI ↔ App)**: `Sources/CLI/SharedModels.swift` — `Session`, `SessionEvent`, `SessionState`, file locking

### Runtime Data

Session files in `~/.vibe-island/sessions/`. CLI and app communicate through JSON files with `flock`-based file locking.

### Pet System

8 pet types (cat, dog, rabbit, fox, penguin, robot, ghost, dragon) × 5 skin tiers (Basic → Glow → Metal → Neon → King) × 8 state animations (idle, thinking, coding, waiting, celebrating, error, compacting, sleeping). 16x16 pixel art format with hex color codes.

### Localization

`en.lproj` + `zh-Hans.lproj` in `Sources/VibeIsland/Resources/`.

## Conventions

- **Project generation**: Always edit `project.yml` then `xcodegen generate`
- **Concurrency**: All singletons `@MainActor`; Swift 6 strict concurrency
- **DI**: dependency injection via `.environment`
- **IPC safety**: All session file I/O must use `flock` locking
- **Comments**: Chinese comments preferred; group code with `MARK:`
- **Do not add unread @Observable properties** — use `@ObservationIgnored` or Swift compiler will warn

## Anti-Patterns

1. **NEVER edit .xcodeproj manually** — fully generated from `project.yml`
2. **DO NOT commit .xcodeproj** — gitignored by design
3. **NEVER crash OpenCode in hook/plugin code** — all error handling must be best-effort
4. **DO NOT write session files without flock locking** — concurrency safety required
5. **NEVER rely on PID alone for session tracking** — always validate process launch time

## Dependencies

- **XcodeGen**: `brew install xcodegen` — required to generate the Xcode project
- No external package dependencies beyond Apple frameworks; `LLMQuotaKit` is a local SPM package
