# Vibe Island

> 你的 AI 编程伙伴住在刘海里 — 监控会话、追踪上下文，用像素宠物为你加油。

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/sonoma/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 为什么选择 Vibe Island？

使用 Claude Code 和 OpenCode 等 AI 工具编程时，你常常会失去对以下信息的追踪：
- 哪些会话正在运行
- 上下文使用了多少
- 何时需要审批操作

**Vibe Island** 通过在 macOS 菜单栏的刘海位置放置一个灵动岛风格的监控器来解决这些问题 — 正好在你 MacBook 刘海吸引注意力的地方。

## 功能特性

- 🏝️ **灵动岛 UI** — 无缝集成到 macOS 菜单栏刘海
- 📊 **上下文监控** — 实时 token 使用追踪，带可视化进度条
- 🐱 **像素宠物** — 8 种宠物类型，5 种皮肤等级，会根据你的编程状态做出反应
- 🔔 **智能通知** — 审批、错误和完成时的声音提醒
- 🎨 **两种主题** — 极客暗黑（像素风）和极简透明（玻璃态）
- 🛠️ **多工具支持** — Claude Code、OpenCode 和 Codex CLI
- 📈 **配额追踪** — 监控多个提供商的 LLM API 配额

## 快速开始

### 前置条件

- macOS 14.0+ (Sonoma)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
- 已安装 Claude Code、OpenCode 或 Codex CLI

### 安装

```bash
# 克隆仓库
git clone https://github.com/twzhan/vibe-island.git
cd vibe-island

# 首次设置
./scripts/dev-setup.sh

# 构建并运行
xcodegen generate
open VibeIsland.xcodeproj
# 在 Xcode 中按 Cmd+R
```

### 配置 Claude Code Hook

```bash
# 为 Claude Code 安装 hook
./scripts/install-claude-hook.sh
```

### 配置 OpenCode 插件

```bash
# 为 OpenCode 安装插件
./scripts/install-opencode-plugin.sh
```

## 面向 AI Agent

本项目专为 AI agent 无缝交互而设计：

1. **克隆和设置**
   ```bash
   git clone https://github.com/twzhan/vibe-island.git
   cd vibe-island
   ./scripts/dev-setup.sh
   ```

2. **构建**
   ```bash
   xcodegen generate
   xcodebuild -scheme VibeIsland -destination 'platform=macOS' build
   ```

3. **运行测试**
   ```bash
   ./scripts/run-tests.sh
   ```

4. **项目结构**
   - `Sources/VibeIsland/` — 主应用代码（SwiftUI + AppKit）
   - `Sources/CLI/` — 用于 hook 集成的 CLI 工具
   - `Packages/LLMQuotaKit/` — LLM 配额监控框架
   - `project.yml` — XcodeGen 配置

5. **关键文件**
   - `Sources/VibeIsland/App/VibeIslandApp.swift` — 应用入口
   - `Sources/CLI/vibe-island.swift` — CLI 入口
   - `Sources/VibeIsland/Views/IslandView.swift` — 主界面

## 架构

```
┌─────────────────────────────────────────────────────────────┐
│                    macOS 菜单栏（刘海）                       │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────┐  ┌─────────────────┐  ┌─────────┐            │
│  │   (     │  │   🐱 42%        │  │    )    │            │
│  │  状态   │  │   上下文        │  │  状态   │            │
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

## 支持的 LLM 提供商

| 提供商 | 配额追踪 |
|--------|----------|
| MiniMax | ✅ |
| MiMo | ✅ |
| 火山引擎 (Ark) | ✅ |
| Kimi (月之暗面) | ✅ |
| Zai | ✅ |

## 贡献

欢迎贡献！请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解指南。

1. Fork 仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m '添加惊人功能'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 许可证

本项目基于 MIT 许可证 — 详情请参阅 [LICENSE](LICENSE) 文件。

## 致谢

- 灵感来自苹果的灵动岛设计
- 使用 SwiftUI 和 AppKit 构建
- 像素艺术为复古游戏美学而生
