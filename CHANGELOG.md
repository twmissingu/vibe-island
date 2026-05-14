# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-05

### Added
- Dynamic Island style menu bar agent for macOS
- Support for multiple LLM quota providers (MiniMax, MiMo, Ark, Kimi, Zai)
- Session tracking for Claude Code and OpenCode
- Context usage monitoring and display
- Pixel pet animation system with 8 pet types
- Two theme modes: Pixel Dark and Glass Transparent
- CLI tool for Claude Code hook integration
- Real-time session state monitoring
- Sound effects for state changes

### Changed
- Unified UI theme management with ThemeManager
- Improved text contrast for both themes
- Standardized UI spacing and formatting

### Fixed
- Session list row spacing inconsistency between themes

## [1.0.1] - 2026-05-14

### Fixed
- **`totalTokensConsumed` double-counting on contextUsage event**: `event.contextTokensUsed` is a snapshot, not a delta — accumulation caused exponential inflation. Changed to no longer derive `totalTokensConsumed` from hook events (transcript/DB paths handle it correctly).
- **`totalTokensConsumed` undercounting in transcript parser**: Only the last message's tokens per 512KB chunk were accumulated; middle messages in large chunks were lost. Now accumulates ALL messages' tokens in each chunk.
- **`totalTokensConsumed` unified strategy**: All paths now consistently treat it as cumulative total. transcript parser accumulates per-chunk message sums; OpenCode DB uses direct assignment from cumulative DB value; contextUsage events no longer touch it.
- **`Session.applyEvent()` missing `totalTokensConsumed`**: App-side event replay now also syncs `totalTokensConsumed` from `contextTokensUsed`.

## Bugfix Patch - 2026-05-13

### Fixed (Critical)
- **State machine divergence**: `SessionState.transition()` differed between CLI and App targets for 6 event types (sessionStart, userPromptSubmit, preToolUse, postToolUse, postCompact) — synced both implementations
- **Cumulative total overcounting**: `PetProgressManager.addCodingMinutes()` received cumulative totals instead of deltas, causing massive minute inflation — added `lastSyncedTodayMinutes`/`lastSyncedTotalMinutes` delta tracking
- **isBlinking mismatch**: App version incorrectly included `completed` and `error` in blinking states — aligned with CLI (only `waitingPermission`, `compacting`)

### Fixed (High)
- **Force unwrap crash in Session.applyEvent()**: `try! JSONEncoder().encode()` replaced with `try?` + `flatMap`
- **Force unwrap in CodingTimeTracker**: Two `!` operators in Calendar date math replaced with `guard let` / `?? Date()`
- **XP conflated with coding minutes**: `ChallengeManager.claimReward()` called `addCodingMinutes(bonusXP)` — changed to logging only
- **Challenge refresh never persisted**: `Date` stored as `TimeInterval` (Double), read as `Date` — always nil, causing daily/weekly refresh every launch — stored as `Date` directly
- **Global mutable state in PreferenceKey**: `nonisolated(unsafe) static var defaultValue` in `RippleEffect.swift` — changed to `let`
- **Missing Sendable conformances**: `ProcessInfo`, `PluginSessionFile` — added `Sendable`

### Fixed (Medium)
- **Bundle ID typo**: `com.twissingu.VibeIsland` → `com.twmissingu.VibeIsland` (2 files)
- **Dead `??` operator**: `defaults.integer(forKey:)` returns non-optional, `??` never triggered — replaced with `as? Int`
- **Unused `type` parameter**: `isGoalAchievedToday(type:)` always checked `lastDailyGoalDate` regardless of type — now dispatches on type
- **Dead code in PetTransitionAnimator**: All 8 `apply*` methods returned `EmptyView()`; `applyTransition()` never called — removed
- **Unused import**: `CoreGraphics` in DynamicIslandPanel, `AppKit` in CodingTimeStatsView — removed
- **Redundant watcher**: `SessionFileWatcher.shared.startWatching()` called without callback in `StateManager` — removed

### Fixed (Low)
- **`var` should be `let`**: `HookHandler.swift` `var toolUsage = session.toolUsage` never mutated
- **Hardcoded particle emission center**: Absolute (32,32) instead of relative to view bounds — removed
- **`AchievementProgress.progress` always 1.0**: Formula `currentValue / max(1, currentValue)` — added `targetValue` field with real division
