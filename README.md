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
- 🔔 **Smart Notifications** — Sound alerts for approvals, errors, and completions
- 🎨 **Two Themes** — Pixel Dark (geeky) and Glass Transparent (minimal)
- 🛠️ **Multi-Tool Support** — Claude Code, OpenCode, and Codex CLI
- 📈 **Quota Tracking** — Monitor LLM API quotas from multiple providers

## Quick Start

### Prerequisites

- macOS 14.0+ (Sonoma)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- Claude Code, OpenCode, or Codex CLI installed

### Installation

```bash
# Clone the repository
git clone https://github.com/twzhan/vibe-island.git
cd vibe-island

# First-time setup
./scripts/dev-setup.sh

# Build and run
xcodegen generate
open VibeIsland.xcodeproj
# Press Cmd+R in Xcode
```

### Configure Claude Code Hook

```bash
# Install the hook for Claude Code
./scripts/install-claude-hook.sh
```

### Configure OpenCode Plugin

```bash
# Install the plugin for OpenCode
./scripts/install-opencode-plugin.sh
```

## For AI Agents

This project is designed for seamless AI agent interaction:

1. **Clone and Setup**
   ```bash
   git clone https://github.com/twzhan/vibe-island.git
   cd vibe-island
   ./scripts/dev-setup.sh
   ```

2. **Build**
   ```bash
   xcodegen generate
   xcodebuild -scheme VibeIsland -destination 'platform=macOS' build
   ```

3. **Run Tests**
   ```bash
   ./scripts/run-tests.sh
   ```

4. **Project Structure**
   - `Sources/VibeIsland/` — Main app code (SwiftUI + AppKit)
   - `Sources/CLI/` — CLI tool for hook integration
   - `Packages/LLMQuotaKit/` — LLM quota monitoring framework
   - `project.yml` — XcodeGen configuration

5. **Key Files**
   - `Sources/VibeIsland/App/VibeIslandApp.swift` — App entry point
   - `Sources/CLI/vibe-island.swift` — CLI entry point
   - `Sources/VibeIsland/Views/IslandView.swift` — Main UI

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
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │  Claude  │    │ OpenCode │    │  Codex   │
    │  Code    │    │          │    │   CLI    │
    └──────────┘    └──────────┘    └──────────┘
           │               │               │
           └───────────────┼───────────────┘
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

## Supported LLM Providers

| Provider | Quota Tracking |
|----------|----------------|
| MiniMax | ✅ |
| MiMo | ✅ |
| Ark (Volcengine) | ✅ |
| Kimi | ✅ |
| Zai | ✅ |

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
