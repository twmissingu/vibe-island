# Vibe Island

> 你的 AI 编程伙伴住在刘海里 — 监控会话、追踪上下文，用像素宠物为你加油。

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/sonoma/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

## 为什么选择 Vibe Island？

使用 Claude Code 和 OpenCode 等 AI 工具编程时，关键信息被埋没了：

- **哪些会话在运行？** — 开了 3 个终端、2 个 VS Code 窗口，哪些在工作？
- **上下文还剩多少？** — AI 上下文窗口悄无声息地填满。到上限时，工作成果会丢失。
- **AI 什么时候需要你？** — 权限请求、错误、完成—没有通知就会错过。

**Vibe Island** 在你 MacBook 的刘海位置放置了一个灵动岛风格的监控器。一眼看去：活跃会话、上下文使用率、工具使用次数，还有一个对一切做出反应的像素宠物。

---

## 功能特性

- 🏝️ **灵动岛 UI** — 融入 macOS 刘海。空闲时紧凑，点击展开 3 个标签：会话列表、上下文使用率、每日统计。
- 📊 **会话监控** — 实时追踪 Claude Code 和 OpenCode 会话。显示工具使用次数、上下文百分比、活跃子代理。
- 🐱 **像素宠物** — 8 种宠物 × 5 个皮肤等级。通过编码解锁。每种宠物对 AI 状态做出反应——出错时抖动、完成时庆祝、压缩时发光。
- 🎯 **每日统计** — 今日编码时长、工具使用排名、每日目标进度。都在展开面板里。
- 🔊 **智能通知** — 只在关键事件（权限请求、错误）时播放提示音。冷却机制防止通知疲劳。
- 🎨 **两种主题** — 极客暗黑（等宽字体、ASCII 分割线）和极简透明（毛玻璃、状态色光晕）。
- 🛠️ **多工具支持** — Claude Code 和 OpenCode，并排显示。

---

## 面向用户

### 系统要求

- **macOS 14.0+** (Sonoma)
- Apple Silicon (M1/M2/M3/M4) 或 Intel Mac，有刘海（推荐）或标准菜单栏
- Claude Code 和/或 OpenCode（可选——Vibe Island 也可以当独立宠物岛使用）

### 快速开始

#### 1. 下载与安装

1. 前往 [GitHub Releases](https://github.com/twzhan/vibe-island/releases) 下载 `VibeIsland.dmg`。
2. 双击 DMG，将 **VibeIsland.app 拖入应用程序文件夹**。
3. 首次启动时，macOS 门禁可能显示：
   > **"VibeIsland.app" 无法打开，因为无法验证开发者。**
   
   右键 → **打开** → 点击 **"打开"**。运行一次后即可正常使用。

#### 2. 首次启动

启动 Vibe Island。你会在刘海位置看到 `( ^_^ )`——一只打瞌睡的像素宠物。点击展开面板。

**如果检测到 Claude Code 或 OpenCode 正在运行**，Vibe Island 会直接在面板内提示安装 hook/插件——无需在设置中翻找。

**如果没有检测到 AI 工具**，会显示引导卡片。或者就让它开着——宠物很可爱。

#### 3. 配置 Hook（获取实时会话数据）

点击展开面板的齿轮图标 → **插件** 部分：
- **Claude Code**：点击 Claude Code 旁的"安装" → 授权访问 `~/.claude` 目录
- **OpenCode**：点击 OpenCode 旁的"安装"

搞定。会话数据会立刻出现在岛中。

### 调试

```bash
VIBE_ISLAND_DEBUG=1 open /Applications/VibeIsland.app
# 日志 → ~/.vibe-island/hook-debug.log
```

---

## 面向开发者

### 前置条件

- macOS 14.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
- Claude Code / OpenCode（可选，用于测试 hook 集成）

### 构建

```bash
git clone https://github.com/twzhan/vibe-island.git
cd vibe-island

# 首次设置（检查依赖、生成 Xcode 项目、类型检查 CLI）
./scripts/dev-setup.sh

# 生成 Xcode 项目（修改 project.yml 后必须运行）
xcodegen generate
open VibeIsland.xcodeproj
# 按 Cmd+R
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

### CLI 类型检查（无需 Xcode）

```bash
cd Sources/CLI && swiftc -typecheck -target arm64-apple-macosx14.0 \
  vibe-island.swift HookHandler.swift SharedModels.swift
```

### 项目结构

```
Sources/VibeIsland/      — 主应用（SwiftUI + AppKit）
Sources/CLI/             — CLI 工具（hook 集成、会话文件写入）
Packages/LLMQuotaKit/    — LLM 配额监控框架
project.yml              — XcodeGen 项目配置
scripts/                 — 构建、发布、设置脚本
Tests/                   — 单元测试 + UI 测试
```

---

## 面向 AI Agent

本项目专为 AI agent 的无缝交互而设计：

1. **克隆与设置**
   ```bash
   git clone https://github.com/twzhan/vibe-island.git
   cd vibe-island
   brew install xcodegen
   ./scripts/dev-setup.sh
   ```

2. **关键文件**
   - `Sources/VibeIsland/App/VibeIslandApp.swift` — 应用入口，面板创建
   - `Sources/CLI/vibe-island.swift` — CLI 入口，`hook <EventType>` 处理 stdin JSON
   - `Sources/CLI/SharedModels.swift` — Session/SessionEvent/SessionState 模型（在 App target 中重复）
   - `Sources/VibeIsland/Views/IslandView.swift` — 主灵动岛 UI（紧凑 + 展开）

3. **约定**
   - Swift 6 严格并发，所有单例 `@MainActor`
   - MVVM + `@Observable`，通过 `.environment` 依赖注入
   - 所有会话文件 I/O 使用 `flock` 锁
   - JSON 写入不使用 `.atomic`（会改 inode，破坏 DispatchSource）
   - CLI 和 App 的模型是重复的——`SessionState.transition()` 和 `isBlinking` 必须保持同步

---

## 架构

```
┌──────────────────────────────────────────────────────────────┐
│                     macOS 菜单栏（刘海）                      │
├──────────────────────────────────────────────────────────────┤
│  ┌──────┐  ┌──────────────┐         ┌──────┐               │
│  │  (   │  │  🐱 42%      │         │   )  │               │
│  │  状态  │  │  上下文     │   刘海   │  状态 │               │
│  └──────┘  └──────────────┘         └──────┘               │
└──────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
  ┌─────────────┐              ┌──────────────┐
  │ Claude Code │              │   OpenCode   │
  │   (hook)    │              │  (plugin)    │
  └──────┬──────┘              └──────┬───────┘
         │                            │
         └──────────┬─────────────────┘
                    ▼
           ┌────────────────┐
           │  SessionManager │  ← 聚合所有会话
           │  + FileWatcher  │  ← DispatchSource 监听 JSON 文件
           └────────┬───────┘
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
  ┌────────────┐       ┌──────────────┐
  │ IslandView │       │ ExpandedPanel │
  │ (紧凑)     │       │ 3 标签 + 宠物  │
  └────────────┘       └──────────────┘
```

**数据流：** Claude Code hook 写入 JSON → CLI 写入 `~/.vibe-island/sessions/<pid>.json` → `SessionFileWatcher`（DispatchSource）检测变更 → `SessionManager` 更新 → `IslandView` 重渲染。

---

## 贡献

请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解指南。欢迎所有贡献——bug 修复、新功能、像素艺术、音效。

- Fork → 功能分支 → PR
- 修改 project.yml 后运行 `xcodegen generate`
- 用 `./scripts/run-tests.sh` 运行测试
- 保持 CLI ↔ App 模型同步

---

## 许可证

MIT © 2026 twzhan — 详见 [LICENSE](LICENSE)

## 致谢

- 灵感来自苹果的灵动岛设计
- 使用 SwiftUI + AppKit 构建
- 16×16 像素艺术由项目贡献者创作
