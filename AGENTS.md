# AGENTS.md — Vibe Island Developer Instructions

**Platform:** macOS 14.0+ | **Swift:** 6.0 | **No external dependencies**

## CORE COMMANDS

```bash
./scripts/dev-setup.sh              # first-time setup (checks deps, generates project, type-checks CLI)
xcodegen generate                    # after ANY change to project.yml
./scripts/run-tests.sh              # run all tests (hook format test + Xcode unit tests)
./scripts/build-release.sh          # clean Release build + DMG

# CLI typecheck (no Xcode needed — must cd into Sources/CLI)
cd Sources/CLI && swiftc -typecheck -target arm64-apple-macosx14.0 vibe-island.swift HookHandler.swift SharedModels.swift

# Xcode tests
xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests
xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests/TestClass/testMethodName
```

## TESTING QUIRKS

- `run-tests.sh` runs `hook_format_test.swift` as a **standalone Swift script** (`swift Tests/.../hook_format_test.swift`) **before** xcodebuild — it is NOT an XCTest
- `hook_format_test.swift` and `dispatch_source_test.swift` are **excluded** from the Xcode test target in `project.yml`
- Tests use `@testable import VibeIsland`; create test instances via `SessionManager.makeForTesting()`
- UI tests live in `Tests/VibeIslandUITests/`
- **SessionStateTests must be updated when `transition()` or `isBlinking` changes** — tests assert exact state machine behavior; update both `transition()` and tests together

## BUILD TARGETS (from project.yml)

| Target | Type | Key Info |
|--------|------|----------|
| **VibeIsland** | macOS App | Menu bar agent (LSUIElement=true), depends on LLMQuotaKit |
| **VibeIslandCLI** | CLI Tool | Product name `vibe-island`; invoked by Claude Code hooks via stdin JSON |
| **LLMQuotaKit** | Framework | Local SPM package at `Packages/LLMQuotaKit/` |
| **VibeWidget** | App Extension | **Disabled** — commented out in project.yml |

## MODEL DUPLICATION WARNING

`Sources/CLI/SharedModels.swift` and `Sources/VibeIsland/Models/` contain **duplicated model types** (Session, SessionEvent, SessionState, ToolUsage, SubagentInfo, SessionError, FileLock). CLI and App are independent targets and cannot share code.

**Must keep in sync** when modifying:
- `SessionState.transition(from:event:)` — MUST be identical in both files
- `SessionState.isBlinking` — MUST be identical in both files
- `Session` CodingKeys, encode/decode logic
- `SessionEvent` fields (CLI version lacks `pid`/`pidStartTime`; add if App adds more)
- `escapeSQL`, `runSQL`, `getOpenCodeModelContextLimit` — duplicated in `HookHandler.swift` + `ContextMonitor.swift`

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Add new LLM quota provider | `Packages/LLMQuotaKit/Sources/LLMQuotaKit/Providers/` | Implement `QuotaProvider` protocol; add case to `ProviderType` in `Models/QuotaInfo.swift` |
| Modify session tracking | `Sources/VibeIsland/Services/` | SessionManager |
| Change Dynamic Island UI | `Sources/VibeIsland/Views/` + `Sources/VibeIsland/Window/` | IslandView + DynamicIslandPanel |
| Add pixel pet animation | `Sources/VibeIsland/Pet/` | PetAnimations, PetEngine |
| Modify CLI hook handling | `Sources/CLI/` | vibe-island.swift + HookHandler + SharedModels (shared with app) |
| Change project structure | `project.yml` | Regenerate with `xcodegen generate` |

## LLMQuotaKit STRUCTURE

- **Providers/**: 5 implementations (MiniMax, MiMo, Ark, Kimi, Zai) + `QuotaProvider` protocol
- **Models/**: `QuotaInfo`, `QuotaError`, `ProviderType`, `AppSettings`, `ProviderConfig`
- **Storage/**: Secure keychain storage for API keys + app group shared defaults
- **Networking/**: Shared `NetworkClient` with 15s timeout

## CONVENTIONS

- **Project generation**: Always edit `project.yml` then `xcodegen generate`; **NEVER edit .xcodeproj manually**
- **Concurrency**: All singletons `@MainActor`; Swift 6 strict concurrency
- **Architecture**: MVVM + `@Observable`; dependency injection via `.environment`
- **IPC safety**: All session file I/O must use `flock` locking
- **Comments**: Chinese comments preferred; group code with `MARK:`
- **State priority**: Approval > Error > Compression > Coding > Thinking > Waiting > Completed > Idle
- **JSON writes**: NEVER use `.atomic` write option — atomic writes change the inode, breaking DispatchSource file monitoring. CLI has `flock` for safety; App reads via DispatchSource which tracks the original fd.
- **Deltas over totals**: When syncing to PetProgressManager, always compute and send deltas. Passing cumulative totals causes massive double-counting.

## ANTI-PATTERNS

1. **NEVER edit .xcodeproj manually** — fully generated from `project.yml`
2. **DO NOT commit .xcodeproj** — gitignored by design
3. **NEVER crash OpenCode in hook/plugin code** — all error handling must be best-effort
4. **DO NOT write session files without flock locking** — concurrency safety required
5. **NEVER rely on PID alone for session tracking** — always validate process launch time
6. **DO NOT add unread @Observable properties without @ObservationIgnored** — Swift compiler warnings
7. **NEVER use force-unwrap (`try!`, `!`, `as!`) in production code** — always use `try?`, `guard let`, or `as?`
8. **DO NOT pass cumulative values to addCodingMinutes** — always track last-synced and compute delta
9. **NEVER leave `.xcodeproj` change in git** — always add `.xcodeproj/` to `.gitignore` before committing
10. **DO NOT use `nonisolated(unsafe)` for PreferenceKey defaultValue** — use `let` instead of `var`
11. **DO NOT use `DispatchQueue.main.asyncAfter` from non-@MainActor View structs** — Swift 6 concurrency

## ARCHITECTURE NOTES

- **CLI ↔ App IPC**: CLI writes `~/.vibe-island/sessions/<pid>.json`; app reads via `SessionFileWatcher` (DispatchSource)
- **OpenCode monitoring**: Plugin Hook → session files in `~/.vibe-island/opencode-sessions/`
- **SessionManager**: Manages all tool sessions (Claude Code via CLI hook, OpenCode via OpenCodeMonitor sync); island always shows highest-priority state
- **Blinking indicators**: Only `waitingPermission` and `compacting` blink; `completed` and `error` are constant color
- **Pet system**: 8 pet types × 5 skin tiers × 8 state animations; 16x16 pixel art with hex colors
- **Localization**: `en.lproj` + `zh-Hans.lproj` in `Sources/VibeIsland/Resources/`

## ENTRY POINTS

- **App**: `Sources/VibeIsland/App/VibeIslandApp.swift` — creates `DynamicIslandPanel`, calls `StateManager.startMonitoring()`
- **CLI**: `Sources/CLI/vibe-island.swift` — `hook <EventType>` reads stdin JSON, delegates to `HookHandler`
- **Shared models (CLI ↔ App)**: `Sources/CLI/SharedModels.swift` — duplicated in `Sources/VibeIsland/Models/`

## RUNTIME DATA

- Session files: `~/.vibe-island/sessions/<pid>.json` (flock-locked)
- App group: `group.com.twmissingu.VibeIsland`
- Bundle ID prefix: `com.twmissingu`
- OpenCode plugin: `./scripts/install-opencode-plugin.sh`
- Debug log: `~/.vibe-island/hook-debug.log` (enabled via `VIBE_ISLAND_DEBUG=1`)

## KNOWN BUG PATTERNS (from 10-round code review)

These were fixed in a 10-round review (May 2026). Watch for them in new code:

| Pattern | File(s) | Fix |
|---------|---------|-----|
| `defaults.integer(forKey:)` used with `??` operator | `PetProgressManager.swift` | Use `defaults.object(forKey:) as? Int` |
| Force-unwrap in Calendar date math | `CodingTimeTracker.swift` | Use `guard let` or `?? Date()` |
| `try! JSONEncoder().encode()` | `Session.swift` | Use `try?` with `flatMap` |
| Cumulative total passed instead of delta | `SessionManager.swift` | Track `lastSynced` and compute delta |
| Bundle ID typo `twissingu` → `twmissingu` | `ContextMonitor.swift`, `ErrorPresenter.swift` | Fix string |
| `Date` stored as `TimeInterval`, read as `Date` | `ChallengeManager.swift` | Store `Date` directly |
| Dead code in ViewModifier (all apply* return EmptyView) | `PetTransitionAnimator.swift` | Remove dead methods, add real offset/rotation |
| `nonisolated(unsafe) static var` in PreferenceKey | `RippleEffect.swift` | Use `let` |
| Unused `type` parameter | `PetProgressManager.swift` | Match parameter to correct date field |
| XP treated as coding minutes | `ChallengeManager.swift` | Remove `addCodingMinutes(bonusXP)` |
| `SessionFileWatcher.shared` started without callback | `QuotaViewModel.swift` | Remove redundant start/stop |
