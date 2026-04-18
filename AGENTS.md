# PROJECT KNOWLEDGE BASE

**Generated:** 2026-04-17
**Branch:** main

## OVERVIEW
Vibe Island — macOS menu bar app that monitors AI coding tools (Claude Code, OpenCode, Codex CLI) and displays their status via a "Dynamic Island" style UI at the Mac notch. Includes pixel pet animations, sound notifications, and API quota monitoring widgets. Built with Swift 6.0, SwiftUI + AppKit for macOS 14.0+.

## STRUCTURE
```
llm-quota-island/
├── Sources/VibeIsland/          # Main app target
│   ├── App/                     # App entry
│   ├── Services/                # Core services (monitoring, session management)
│   ├── Views/                   # SwiftUI views
│   ├── ViewModels/              # View models
│   ├── Models/                  # Data models
│   ├── Window/                  # Dynamic Island panel window management
│   ├── Pet/                     # Pixel pet engine and animations
│   └── Resources/               # Assets, sounds, localization
├── Sources/CLI/                 # VibeIslandCLI target (vibe-island binary)
├── Widget/                      # VibeWidget macOS widget target
├── Packages/LLMQuotaKit/        # Shared SPM framework for quota API providers
├── Tests/VibeIslandTests/       # Unit/integration/UI tests
├── scripts/                     # Dev setup, build, test, release scripts
└── project.yml                  # XcodeGen project configuration (source of truth)
```

## WHERE TO LOOK
| Task | Location | Notes |
|------|----------|-------|
| Add new LLM quota provider | `Packages/LLMQuotaKit/Sources/LLMQuotaKit/Providers/` | Implement QuotaProvider protocol |
| Modify session tracking | `Sources/VibeIsland/Services/` | SessionManager, MultiToolAggregator |
| Change Dynamic Island UI | `Sources/VibeIsland/Views/` + `Sources/VibeIsland/Window/` | IslandView + DynamicIslandPanel |
| Add pixel pet animation | `Sources/VibeIsland/Pet/` | PetAnimations, PetEngine |
| Modify CLI hook handling | `Sources/CLI/` | vibe-island.swift + HookHandler |
| Run tests | `Tests/VibeIslandTests/` | Unit, integration, UI tests |
| Change project structure | `project.yml` | Regenerate with `xcodegen generate` |

## ARCHITECTURE FACTS
- 4 build targets:
  1. `VibeIsland`: Main macOS menu bar app (Dynamic Island UI at notch)
  2. `VibeIslandCLI`: `vibe-island` binary, invoked by Claude Code/OpenCode hooks
  3. `VibeWidget`: macOS widget for API quota display
  4. `LLMQuotaKit`: Shared SPM package for quota API providers
- Platform: macOS 14.0+ (Sonoma), Swift 6.0
- IPC: CLI ↔ App communicate via JSON files in `~/.vibe-island/sessions/` using `flock` locking
- Pattern: MVVM + @Observable, singletons marked `@MainActor`
- App entry: `Sources/VibeIsland/App/VibeIslandApp.swift`
- CLI entry: `Sources/CLI/vibe-island.swift`

## LLMQuotaKit ARCHITECTURE (Shared Framework)
The `LLMQuotaKit` framework contains all reusable quota-related functionality:
- **Providers/**: 5 LLM provider implementations (MiniMax, MiMo, Ark, Kimi, Zai) + base `QuotaProvider` protocol
- **Models/**: Shared data models (`QuotaInfo`, `QuotaError`, `ProviderType`)
- **Storage/**: Secure keychain storage for API keys + app group shared defaults
- **Networking/**: Shared `NetworkClient` with 15s timeout and standardized error handling

To add a new provider:
1. Create new file in `Providers/` implementing `QuotaProvider` protocol
2. Add your provider to `ProviderType` enum in `Models/QuotaInfo.swift`
3. Implement `validateKey()` for connectivity check and `fetchQuota()` for quota retrieval

## CONVENTIONS
- **Project generation**: Always edit `project.yml` then run `xcodegen generate`; **NEVER edit .xcodeproj manually**
- **Concurrency**: All singletons must be marked `@MainActor`; entire codebase uses Swift 6 concurrency safe
- **Architecture pattern**: MVVM + @Observable for all view-related code
- **IPC safety**: All session file operations (read/write) must use `flock` locking
- **Comments**: Chinese comments are preferred; group code with `MARK:` comments
- **State priority**: Always maintain priority order: Approval > Error > Compression > Coding > Thinking > Waiting > Completed > Idle

## ANTI-PATTERNS (THIS PROJECT)
1. ❌ **NEVER edit .xcodeproj files manually** — they are fully generated from `project.yml`
2. ❌ **DO NOT commit .xcodeproj to git** — they are gitignored by design
3. ❌ **NEVER crash OpenCode in hook/plugin code** — all error handling must be best-effort
4. ❌ **DO NOT write session files without flock locking** — concurrency safety is required
5. ❌ **NEVER rely on PID alone for session tracking** — always validate process launch time
6. ❌ **DO NOT add @Observable properties that are never read without @ObservationIgnored** — causes Swift compiler warnings

## UNIQUE STYLES
- **OpenCode monitoring**: 4-level fallback architecture (Plugin Hook → SSE event stream → File monitoring → Process detection) for maximum reliability across different usage patterns
- **Aggregate state**: Automatically displays highest priority state across all active sessions from all tools
- **Blinking indicators**: States requiring user attention (waiting permission, context compression) use blinking indicators vs constant color
- **Dual-language**: Full English/Simplified Chinese localization via standard `.lproj` directories

## COMMANDS
```bash
# First-time setup
./scripts/dev-setup.sh

# Generate Xcode project after changing project.yml
xcodegen generate

# Open project in Xcode
open VibeIsland.xcodeproj

# Run all tests (hook format + unit tests)
./scripts/run-tests.sh

# Build release DMG
./scripts/build-release.sh

# CLI typecheck (no Xcode needed)
swiftc -typecheck -target arm64-apple-macosx14.0 Sources/CLI/*.swift

# Test single method
xcodebuild test -scheme VibeIsland -destination 'platform=macOS' -only-testing:VibeIslandTests/TestClass/testMethod
```

## NOTES
- **App group identifier**: `group.com.twmissingu.VibeIsland` (used for shared storage between app, CLI, widget)
- **Bundle ID prefix**: `com.twmissingu` for all targets
- **LSUIElement**: Main app runs as agent with no dock icon
- **OpenCode plugin**: Install via `./scripts/install-opencode-plugin.sh` for best monitoring quality