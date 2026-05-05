# Vibe Island

> Your AI coding companion lives in the notch — monitoring sessions, tracking context, and cheering you on with pixel pets.

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/sonoma/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Why Vibe Island?

When coding with AI tools like Claude Code and OpenCode, you lose track of:
- Which sessions are active
- How much context you've used
- When you need to approve actions

**Vibe Island** solves this by placing a Dynamic Island-style monitor in your macOS menu bar — right where your MacBook's notch already draws attention.

## Features

- 🏝️ **Dynamic Island UI** — Seamlessly integrated into the macOS menu bar notch
- 📊 **Context Monitoring** — Real-time token usage tracking with visual progress bars
- 🐱 **Pixel Pets** — 8 pet types with 5 skin tiers that react to your coding state
- 🔊 **Smart Notifications** — Sound alerts for approvals, errors, and completions
- 🎨 **Two Themes** — Pixel Dark (geeky) and Glass Transparent (minimal)
- 🛠️ **Multi-Tool Support** — Claude Code and OpenCode

---

## For Users

### System Requirements

- **macOS 14.0+** (Sonoma)
- Apple Silicon (M1/M2/M3/M4) or Intel Mac
- Claude Code or OpenCode installed (optional, for full features)

### Installation

#### 1. Download

Go to [GitHub Releases](https://github.com/twzhan/vibe-island/releases) and download the latest `VibeIsland.dmg`.

#### 2. Install

Double-click the DMG file, then **drag VibeIsland.app to your Applications folder**.

#### 3. First Launch (macOS Gatekeeper)

Because Vibe Island is not distributed through the Mac App Store, macOS may show a security warning on first launch:

> **"VibeIsland.app" cannot be opened because the developer cannot be verified.**

**To open the app:**

- **Option 1:** Right-click (or Control-click) on VibeIsland.app → **Open** → click **"Open"** in the dialog.
- **Option 2:** Run this command in Terminal:
  ```bash
  xattr -cr /Applications/VibeIsland.app
  ```
  Then double-click the app normally.

#### 4. First-Run Setup

On first launch, Vibe Island will show an onboarding guide:

1. **Welcome** — Overview of features
2. **Configure Plugins** — Install Claude Code Hook and/or OpenCode Plugin for real-time status
3. **Preferences** — Choose startup, sound, and pet settings
4. **Done** — Start using Vibe Island

You can also configure these later in **Settings** (gear icon in the expanded panel).

### Configure Claude Code Hook

For real-time Claude Code session monitoring, install the hook:

```bash
# Option A: Via Settings UI (recommended)
# Open Vibe Island → Settings → Plugin → Click "Install" next to Claude Code

# Option B: Via command line
./scripts/install-claude-hook.sh
```

### Configure OpenCode Plugin

For real-time OpenCode session monitoring:

```bash
# Option A: Via Settings UI (recommended)
# Open Vibe Island → Settings → Plugin → Click "Install" next to OpenCode

# Option B: Via command line
./scripts/install-opencode-plugin.sh
```

---

## For Developers

### Prerequisites

- macOS 14.0+ (Sonoma)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Claude Code or OpenCode installed (optional)

### Clone and Build

```bash
# Clone the repository
git clone https://github.com/twzhan/vibe-island.git
cd vibe-island

# First-time setup (installs XcodeGen, generates project, type-checks CLI)
./scripts/dev-setup.sh

# Build and run
xcodegen generate
open VibeIsland.xcodeproj
# Press Cmd+R in Xcode
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

### Project Structure

```
Sources/VibeIsland/      — Main app code (SwiftUI + AppKit)
Sources/CLI/             — CLI tool for hook integration
Packages/LLMQuotaKit/    — LLM quota monitoring framework
project.yml              — XcodeGen configuration
scripts/                 — Build and setup scripts
```

### Key Files

| File | Description |
|------|-------------|
| `Sources/VibeIsland/App/VibeIslandApp.swift` | App entry point |
| `Sources/CLI/vibe-island.swift` | CLI entry point |
| `Sources/VibeIsland/Views/IslandView.swift` | Main UI |
| `Sources/VibeIsland/Views/OnboardingView.swift` | First-run onboarding |
| `Sources/VibeIsland/Views/SettingsView.swift` | Settings panel |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    macOS Menu Bar (Notch)                    │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────────────┐  ┌─────────┐            │
│  │   (     │  │   🐱 42%        │  │    )    │            │
│  │  State  │  │   Context       │  │  State  │            │
│  └─────────┘  └─────────────────┘  └─────────┘            │
└─────────────────────────────────────────────────────────────┘
                           │
           ┌───────────────┴───────────────┐
           ▼                               ▼
    ┌──────────┐                    ┌──────────┐
    │  Claude  │                    │ OpenCode │
    │  Code    │                    │          │
    └──────────┘                    └──────────┘
           │                               │
           └───────────────┬───────────────┘
                           ▼
                    ┌──────────────┐
                    │   Session    │
                    │   Manager   │
                    └──────────────┘
                           │
                    ┌──────────────┐
                    │    Island    │
                    │     View     │
                    └──────────────┘
```

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by Apple's Dynamic Island design
- Built with SwiftUI and AppKit
- Pixel art created with love for the retro gaming aesthetic
