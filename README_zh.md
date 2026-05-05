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
- 🔊 **智能通知** — 审批、错误和完成时的声音提醒
- 🎨 **两种主题** — 极客暗黑（像素风）和极简透明（玻璃态）
- 🛠️ **多工具支持** — Claude Code 和 OpenCode

---

## 面向用户

### 系统要求

- **macOS 14.0+** (Sonoma)
- Apple Silicon (M1/M2/M3/M4) 或 Intel Mac
- 已安装 Claude Code 或 OpenCode（可选，用于完整功能）

### 安装

#### 1. 下载

前往 [GitHub Releases](https://github.com/twzhan/vibe-island/releases) 下载最新的 `VibeIsland.dmg`。

#### 2. 安装

双击 DMG 文件，然后 **将 VibeIsland.app 拖入应用程序文件夹**。

#### 3. 首次启动（macOS 门禁）

由于 Vibe Island 未通过 Mac App Store 分发，macOS 在首次启动时可能会显示安全警告：

> **"VibeIsland.app" 无法打开，因为无法验证开发者。**

**打开应用的方法：**

- **方法一：** 右键（或 Control+点击）VibeIsland.app → **打开** → 点击对话框中的 **"打开"**。
- **方法二：** 在终端中运行以下命令：
  ```bash
  xattr -cr /Applications/VibeIsland.app
  ```
  然后正常双击应用。

#### 4. 首次运行设置

首次启动时，Vibe Island 会显示引导流程：

1. **欢迎** — 功能概览
2. **配置插件** — 安装 Claude Code Hook 和/或 OpenCode 插件以获取实时状态
3. **偏好设置** — 选择开机自启、声音和宠物设置
4. **完成** — 开始使用 Vibe Island

你也可以稍后在 **设置**（展开面板中的齿轮图标）中配置这些选项。

### 配置 Claude Code Hook

要实现实时 Claude Code 会话监控，请安装 hook：

```bash
# 方法 A：通过设置界面（推荐）
# 打开 Vibe Island → 设置 → 插件 → 点击 Claude Code 旁边的"安装"

# 方法 B：通过命令行
./scripts/install-claude-hook.sh
```

### 配置 OpenCode 插件

要实现实时 OpenCode 会话监控：

```bash
# 方法 A：通过设置界面（推荐）
# 打开 Vibe Island → 设置 → 插件 → 点击 OpenCode 旁边的"安装"

# 方法 B：通过命令行
./scripts/install-opencode-plugin.sh
```

---

## 面向开发者

### 前置条件

- macOS 14.0+ (Sonoma)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
- 已安装 Claude Code 或 OpenCode（可选）

### 克隆和构建

```bash
# 克隆仓库
git clone https://github.com/twzhan/vibe-island.git
cd vibe-island

# 首次设置（安装 XcodeGen、生成项目、类型检查 CLI）
./scripts/dev-setup.sh

# 构建并运行
xcodegen generate
open VibeIsland.xcodeproj
# 在 Xcode 中按 Cmd+R
```

### 构建发布版 DMG

```bash
./scripts/build-release.sh
# 输出：build/VibeIsland.dmg
```

### 运行测试

```bash
./scripts/run-tests.sh
```

### 项目结构

```
Sources/VibeIsland/      — 主应用代码（SwiftUI + AppKit）
Sources/CLI/             — 用于 hook 集成的 CLI 工具
Packages/LLMQuotaKit/    — LLM 配额监控框架
project.yml              — XcodeGen 配置
scripts/                 — 构建和设置脚本
```

### 关键文件

| 文件 | 说明 |
|------|------|
| `Sources/VibeIsland/App/VibeIslandApp.swift` | 应用入口 |
| `Sources/CLI/vibe-island.swift` | CLI 入口 |
| `Sources/VibeIsland/Views/IslandView.swift` | 主界面 |
| `Sources/VibeIsland/Views/OnboardingView.swift` | 首次运行引导 |
| `Sources/VibeIsland/Views/SettingsView.swift` | 设置面板 |

---

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
