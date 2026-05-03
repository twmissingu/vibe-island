[![English](https://img.shields.io/badge/English-blue.svg)](README.md)
[![中文](https://img.shields.io/badge/中文-red.svg)](README_zh.md)
[![Platform](https://img.shields.io/badge/platform-macOS%2014.0+-blue.svg)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

# Vibe Island

> 你的 AI 编码助手状态，尽在灵动岛 — Dynamic Island UI、像素宠物伙伴、声音提醒和上下文感知，全部集成在一个 macOS 菜单栏应用中。

Vibe Island 实时监控多个 AI 编码工具（Claude Code、OpenCode、Codex CLI），并将会话状态以 Dynamic Island 风格的浮窗展示在 macOS 刘海区域。**这就是开发者的 Dynamic Island。**

## 功能特性

### 多工具会话监控

- **Claude Code** — 原生 Hook 集成，支持 14 种事件类型，零配置启动
- **OpenCode** — JavaScript 插件，四级降级检测（插件 → SSE → 文件 → 进程）
- **Codex CLI** — 通过 `pgrep` 进行进程级检测

### 灵动岛 UI

- 紧凑模式：单行状态固定在刘海区域
- 展开模式：完整的会话详情，包括上下文使用量、工具统计和子代理追踪
- 状态驱动的颜色和动画（思考、编码、等待、错误、压缩）
- 多会话追踪，支持手动/自动固定模式

### 上下文感知

- 实时上下文窗口使用量追踪（已用/总量/剩余 token）
- 输入/输出/推理 token 分类统计
- 按会话统计工具和技能使用情况
- 80% 和 95% 上下文阈值警告通知

### 像素宠物系统

- 8 个宠物伙伴：猫、狗、兔子、狐狸、企鹅、机器人、幽灵、小龙
- 5 个皮肤等级，通过编码时长解锁：Basic → Glow → Metal → Neon → King
- 8 种动画状态，与 AI 工具状态实时同步
- 16x16 像素艺术，十六进制颜色编码

### 声音提醒

- 可配置的会话状态变化音频提示
- 逐事件音量控制和测试按钮

### LLM 额度追踪

- 5 个提供商：小米 MiMo、Kimi、MiniMax、智谱 Z.AI、火山方舟
- macOS Widget 实时显示额度信息

### 游戏化系统

- 成就系统，5 个类别和稀有度等级（普通 → 传说）
- 排行榜：每日、每周、每月、全时排名
- 经验值进度与编码时长和工具使用挂钩

## 快速开始

### 系统要求

- macOS 14.0+（Sonoma）
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`

### 安装

```bash
git clone https://github.com/anthropics/vibe-island.git
cd vibe-island
./scripts/dev-setup.sh
```

在 Xcode 中按 **Cmd+R** 编译运行。

### Claude Code 集成

首次启动时自动安装 Hook。手动安装：

```bash
vibe-island hook SessionStart
vibe-island hook PreToolUse
vibe-island hook PostToolUse
vibe-island hook Stop
```

### OpenCode 集成

```bash
./scripts/install-opencode-plugin.sh
```

### 构建发布版

```bash
./scripts/build-release.sh
```

## 面向 AI Agent

```bash
# 克隆并设置
git clone https://github.com/anthropics/vibe-island.git
cd vibe-island
./scripts/dev-setup.sh

# 构建
xcodegen generate
xcodebuild build -scheme VibeIsland -destination 'platform=macOS'

# 测试（CLI 类型检查）
cd Sources/CLI && swiftc -typecheck -target arm64-apple-macosx14.0 \
  vibe-island.swift HookHandler.swift SharedModels.swift

# 项目结构
# - 修改 project.yml 后运行 xcodegen generate
# - 不要直接编辑 .xcodeproj（它是生成的，已 gitignore）
# - CLI 和 App 通过 Sources/CLI/SharedModels.swift 共享模型
```

## 架构

```
Claude Code hook → stdin JSON → vibe-island CLI → HookHandler
  → 写入会话 JSON 到 ~/.vibe-island/sessions/<pid>.json

SessionFileWatcher (DispatchSource) → 检测文件变化 → SessionManager
OpenCodeMonitor (插件 hook → SSE → 文件监控 → pgrep)
CodexMonitor (进程检测)
  ↓
SessionManager (统一会话存储，按 lastActivity 排序)
  ↓
DynamicIslandPanel (刘海区域 NSPanel) → IslandView
  ↓
SoundManager (音频提示) + PetEngine (像素宠物动画)
```

## 状态优先级

```
审批 > 错误 > 压缩 > 编码 > 思考 > 等待 > 完成 > 空闲
```

会话列表按 `lastActivity` 降序排列（最近活跃在前）。状态优先级仅用于 `aggregateState` 聚合计算。

## 贡献

1. Fork 仓库
2. 创建功能分支（`git checkout -b feature/amazing-feature`）
3. 如需添加新文件，编辑 `project.yml` 后运行 `xcodegen generate`
4. 提交 Pull Request

详见 [CLAUDE.md](CLAUDE.md) 了解开发规范。

## 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)。
