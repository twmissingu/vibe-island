# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Vibe Island** — macOS menu bar app (Swift 6.0, SwiftUI + AppKit) monitoring AI coding tools (Claude Code, OpenCode) with "Dynamic Island" notch UI, pixel pet animations, sound notifications, and API quota widgets.

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

- `run-tests.sh` runs `hook_format_test.swift` as a **standalone Swift script** before xcodebuild — NOT an XCTest
- `hook_format_test.swift` and `dispatch_source_test.swift` are **excluded** from Xcode test target in `project.yml`
- Tests use `@testable import VibeIsland`; create instances via `SessionManager.makeForTesting()`
- **SessionStateTests must be updated when `transition()` or `isBlinking` changes** — tests assert exact state machine behavior

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
  → PreToolUse 事件: 工具调用计数累加
  → 写入 session JSON: ~/.vibe-island/sessions/<pid>.json (flock locking)

OpenCodeMonitor → Plugin Hook → session files in ~/.vibe-island/opencode-sessions/
  ↓
SessionFileWatcher (DispatchSource) → 检测文件变化 → SessionManager
  → Session 模型是单一数据源，UI 直接读取
  → OpenCode 会话: 若无 context_usage，从 SQLite DB 补充
  ↓
DynamicIslandPanel (NSPanel at notch) → IslandView
  → ContextUsageCard / OpenCodeNoContextCard / SessionInfoCard
  ↓
SoundManager (audio cues) + PetEngine (pixel pet animations)
```

#### 上下文数据来源

| 来源 | 数据 | 路径 |
|------|------|------|
| transcript JSONL | token 用量、skill 调用 | CLI `parseTranscriptContext` → Session 文件 |
| PreToolUse hook | 工具调用计数 | CLI `updateToolUsage` → Session 文件 |
| OpenCode SQLite | token 用量、压缩检测 | App `ContextMonitor.fetchContextUsageFromOpenCodeDB` → Session 模型 |

**设计原则**: Session 模型是单一数据源。UI 直接从 Session 构建 `ContextUsageSnapshot`，不经过 ContextMonitor 中转。

### State Priority

`Approval > Error > Compression > Coding > Thinking > Waiting > Completed > Idle`

Only `waitingPermission` and `compacting` blink; `completed` and `error` are constant color.

**Session list sorting**: `sortedSessions` 按 `lastActivity` 降序排列。状态优先级仅用于 `aggregateState` 聚合计算。

### Model Duplication Warning

`Sources/CLI/SharedModels.swift` and `Sources/VibeIsland/Models/` contain duplicated model types (Session, SessionEvent, SessionState, ToolUsage, SubagentInfo, SessionError, FileLock). **Must keep in sync.**
- `SessionState.transition(from:event:)` — MUST be identical
- `SessionState.isBlinking` — MUST be identical
- `escapeSQL`/`runSQL`/`getOpenCodeModelContextLimit` — duplicated in `HookHandler.swift` + `ContextMonitor.swift`

### Where to Look

| Task | Location | Notes |
|------|----------|-------|
| Add LLM quota provider | `Packages/LLMQuotaKit/Sources/LLMQuotaKit/Providers/` | Implement `QuotaProvider` protocol |
| Modify session tracking | `Sources/VibeIsland/Services/SessionManager.swift` | SessionManager |
| Change Dynamic Island UI | `Sources/VibeIsland/Views/IslandView.swift` + `Sources/VibeIsland/Window/` | IslandView + DynamicIslandPanel |
| Add pixel pet animation | `Sources/VibeIsland/Pet/PetAnimations.swift` | PetAnimations (16x16 pixel art with hex colors) |
| Modify CLI hook handling | `Sources/CLI/` | vibe-island.swift + HookHandler + SharedModels |

### Runtime Data

Session files in `~/.vibe-island/sessions/`. CLI and app communicate through JSON files with `flock`-based file locking.

### Pet System

8 pet types × 5 skin tiers × 8 state animations. 16x16 pixel art format with hex color codes.

### Localization

`en.lproj` + `zh-Hans.lproj` in `Sources/VibeIsland/Resources/`.

## Conventions

- **Project generation**: Always edit `project.yml` then `xcodegen generate`
- **Concurrency**: All singletons `@MainActor`; Swift 6 strict concurrency
- **IPC safety**: All session file I/O must use `flock` locking. NEVER use `.atomic` JSON writes (changes inode, breaks DispatchSource)
- **Deltas over totals**: When syncing to PetProgressManager, always compute and send deltas
- **Comments**: Chinese comments preferred; group code with `MARK:`

## Anti-Patterns

1. **NEVER edit .xcodeproj manually** — fully generated from `project.yml`
2. **DO NOT commit .xcodeproj** — gitignored by design
3. **NEVER crash in hook/plugin code** — all error handling must be best-effort
4. **DO NOT write session files without flock locking** — concurrency safety required
5. **NEVER rely on PID alone for session tracking** — always validate process launch time
6. **NEVER use force-unwrap in production code** — always use `try?`, `guard let`, or `as?`
7. **DO NOT use `nonisolated(unsafe) static var` for PreferenceKey** — use `let`
8. **DO NOT use `DispatchQueue.main.asyncAfter` from non-`@MainActor` View structs**

## Dependencies

- **XcodeGen**: `brew install xcodegen` — required to generate the Xcode project
- No external package dependencies beyond Apple frameworks; `LLMQuotaKit` is a local SPM package
