# Vibe Island - AI 工具状态监控平台

> 🏝️ 你的 AI 编码助手状态，尽在灵动岛

[![Platform](https://img.shields.io/badge/platform-macOS%2014.0+-blue.svg)](https://developer.apple.com/macos/)
[![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## ✨ 功能特性

### 🎯 核心功能

- **多工具监控** — 同时监控 Claude Code、OpenCode、Codex 的运行状态
- **实时状态感知** — 通过 Hook 系统实时感知 AI 工具的状态变化
- **灵动岛 UI** — 优雅的 macOS 菜单栏动态岛效果
- **声音提醒** — 4 种核心提示音（审批请求/任务完成/错误/上下文压缩）
- **上下文感知** — 实时监控 Claude Code 上下文使用率，超阈值自动警告

### 🐾 像素宠物

- **8 款可爱宠物** — 猫、狗、兔子、狐狸、企鹅、机器人、幽灵、小龙
- **8 种状态动画** — 空闲/思考/编码/等待/庆祝/错误/压缩/睡眠
- **状态联动** — 宠物动画与 AI 工具状态实时同步

### 🔧 技术特性

- **多级别监控架构** — 每种 AI 工具采用最适合的监控策略
- **并发安全** — flock 文件锁 + DispatchSource 防抖动
- **多状态聚合** — 智能优先级排序（审批 > 错误 > 运行 > 空闲）
- **Widget 支持** — macOS Widget 实时显示 API 额度

---

## 📸 截图

> 截图待添加

---

## 🚀 快速开始

### 系统要求

- macOS 14.0 (Sonoma) 或更高版本
- Xcode 15+ (开发)

### 安装方式

#### 方式一：从 GitHub Releases 下载

1. 访问 [Releases](https://github.com/yourusername/vibe-island/releases) 页面
2. 下载最新的 `.dmg` 文件
3. 打开 dmg，将 VibeIsland.app 拖到 Applications 文件夹

#### 方式二：从源码编译

```bash
# 克隆项目
git clone https://github.com/yourusername/vibe-island.git
cd vibe-island

# 安装依赖
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate

# 打开项目
open VibeIsland.xcodeproj

# 在 Xcode 中编译运行 (Cmd+R)
```

### CLI 工具编译

CLI 工具 `vibe-island` 由 Xcode 项目自动构建为 `VibeIslandCLI` target。编译主应用后，CLI 可执行文件会出现在构建产物中：

```bash
# 完整构建后，CLI 可在 Products 目录找到
# 或者手动通过 swiftc 编译 CLI 单独测试：
swiftc -typecheck -target arm64-apple-macosx14.0 Sources/CLI/*.swift
```

---

## 📖 使用指南

### 首次启动

1. 启动 VibeIsland.app
2. 打开设置（菜单栏图标 → 设置）
3. 配置你的 API Keys
4. 选择要监控的平台

### 配置 Claude Code Hook

1. 打开 VibeIsland 设置
2. 进入 "Claude Code Hook" 部分
3. 点击 "安装 Hook"
4. 重启 Claude Code 使 Hook 生效

### 测试 Hook

```bash
# 模拟 SessionStart 事件
echo '{"session_id":"test_001","cwd":"/tmp/test","hook_event_name":"SessionStart"}' | vibe-island hook SessionStart

# 查看会话文件
cat ~/.vibe-island/sessions/*.json
```

### 自定义宠物

1. 打开设置 → 像素宠物
2. 启用宠物开关
3. 选择你喜欢的宠物
4. 调整宠物大小

---

## 🏗️ 架构详解

### 三种 AI 工具的监控方式

Vibe Island 针对不同的 AI 编码工具，采用了各自最适合的监控策略：

#### Claude Code — Hook 系统（事件驱动）

Claude Code 提供了完善的 [Hook 机制](https://docs.anthropic.com/en/docs/claude-code/hooks)，可以在会话生命周期的关键事件触发时执行外部命令。Vibe Island 的工作流程：

```
Claude Code 触发事件（如用户提交提示、工具调用、权限请求等）
    ↓
执行 vibe-island hook <EventType>  （Claude Code 通过 stdin 传入 JSON）
    ↓
CLI 解析 JSON，应用状态转换逻辑
    ↓
写入 ~/.vibe-island/sessions/<pid>.json  （flock 文件锁保护并发安全）
    ↓
SessionFileWatcher 检测到文件变化（DispatchSource 监听 .write 事件）
    ↓
SessionManager 更新聚合状态
    ↓
IslandView 更新颜色 + SoundManager 播放提示音
```

这是**事件驱动**的实时监控，延迟极低（<100ms），能精确捕获 14 种事件类型。

#### OpenCode — 四级降级架构

OpenCode 的监控采用四级降级策略，按可靠性和实时性从高到低排列：

| 级别 | 方式 | 说明 | 可靠性 |
|------|------|------|--------|
| **L1** | Plugin Hook | OpenCode 插件在事件触发时写入 JSON 文件 | ⭐⭐⭐⭐⭐ |
| **L2** | SSE 事件流 | 连接 `localhost:4040/global/event`，解析实时事件 | ⭐⭐⭐⭐ |
| **L3** | 文件监控 | 监控 `~/.local/share/opencode/storage/` 目录变化 | ⭐⭐⭐ |
| **L4** | 进程检测 | `pgrep -f opencode` 检测进程是否存在 | ⭐⭐ |

**工作原理**：系统优先尝试 L1（插件 Hook），如果插件未安装或不可用，自动降级到 L2（SSE 长连接），如果 OpenCode 未以 serve 模式运行，降级到 L3（文件轮询），最终兜底到 L4（仅检测进程是否存在）。每一级都有独立的优先级数值，只有更高级别的数据才会覆盖低级别的结果。

```
┌─────────────────────────────────────────────┐
│  OpenCode 监控（四级降级）                    │
├─────────────────────────────────────────────┤
│  L1 Plugin ──> ~/.vibe-island/              │
│                  opencode-sessions/          │
│       ↓ (不可用)                             │
│  L2 SSE ─────> localhost:4040/              │
│                  global/event                │
│       ↓ (不可用)                             │
│  L3 File ────> ~/.local/share/              │
│                  opencode/storage/           │
│       ↓ (不可用)                             │
│  L4 Process ─> pgrep -f opencode            │
└─────────────────────────────────────────────┘
```

> **为什么需要四级降级？** OpenCode 的使用场景多样：有些用户安装插件（完整功能），有些用户仅 CLI 使用（无插件），有些用户使用 serve 模式（有 SSE），有些用户本地运行（仅文件）。四级降级确保无论用户如何使用 OpenCode，Vibe Island 都能提供不同程度的监控。

#### Codex CLI — 进程检测

Codex CLI 目前不提供 Hook 或 SSE 接口，因此 Vibe Island 采用**进程级检测**：

- 使用 `pgrep -lf codex/codex-cli` 检测进程
- 通过 `lsof` 获取进程工作目录 (cwd)
- 提供基础运行状态（运行中/未运行）

这是最基础的监控级别，仅能告知 Codex 是否在运行，无法感知具体状态。

### 三种工具的对比

| 维度 | Claude Code | OpenCode | Codex CLI |
|------|-------------|----------|-----------|
| **监控方式** | Hook 事件驱动 | 四级降级 | 进程检测 |
| **状态粒度** | 14 种事件 → 8 种状态 | 6+ 种事件 → 8 种状态 | 运行/未运行 |
| **实时性** | < 100ms | < 500ms (L1/L2) | 2s (轮询) |
| **配置要求** | 安装 Hook | 可选安装插件 | 无需配置 |

### 数据流总览

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Claude Code  │    │   OpenCode   │    │   Codex CLI  │
│  (Hook)      │    │  (4-level)   │    │  (pgrep)     │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ HookHandler  │    │OpenCodeMonitor│   │ CodexMonitor │
│   (CLI)      │    │  (syncs to   │    │              │
│              │    │SessionManager)│    │              │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌──────────────────────────────────────────────────────┐
│                   SessionManager                      │
│   (DispatchSource 监听 + registerExternalSession)     │
│          (aggregateState → IslandView)                │
└──────────────────────────────────────────────────────┘
```

---

## 🎨 状态指示

灵动岛通过**左侧状态指示器**和**颜色**直观展示当前最高优先级会话的状态：

### 状态颜色一览

| 状态 | 颜色 | 指示器 | 说明 |
|------|------|--------|------|
| 空闲 | ⚫ 黑色 | 常亮圆点 | 无活跃会话 |
| 思考 | 🟡 黄色 | 常亮圆点 | 正在处理用户提示 |
| 编码 | 🟢 绿色 | 常亮圆点 | 正在调用工具（Bash/Read/Write 等） |
| 等待 | 🟠 橙色 | 常亮圆点 | 等待用户输入 |
| 审批 | 🟡 黄色 | **闪烁圆点** | 等待用户批准权限（需要操作） |
| 错误 | 🔴 红色 | 常亮圆点 | 会话出错 |
| 压缩 | 🟠 橙色 | **闪烁圆点** | 上下文压缩中 |
| 完成 | 🟢 绿色 | 常亮圆点 | 会话已完成 |

> **闪烁**表示需要关注但不紧急的状态（如等待权限审批、上下文压缩中）。

### 多会话优先级

当你同时运行多个 AI 工具窗口时，灵动岛**始终显示最高优先级的状态**，而非简单切换：

```
优先级从高到低：
  审批 (0) > 错误 (1) > 压缩 (2) > 编码 (3) > 思考 (4) > 等待 (5) > 完成 (6) > 空闲 (7)
```

代码中的优先级与上述排序完全一致。

这意味着：如果有一个 Claude Code 窗口在编码（蓝色），另一个 OpenCode 窗口在等待审批（紫色闪烁），灵动岛会**优先显示紫色闪烁**，因为审批需要你的操作。当审批完成后，自动切换到下一个最高优先级的状态。

---

## 🔌 支持的 AI 工具

| 工具 | 监控方式 | 状态 | 详细程度 |
|------|---------|------|---------|
| **Claude Code** | Hook 系统 | ✅ 完整支持 | 14 种事件类型 |
| **OpenCode** | 四级降级 | ✅ 支持 | 6+ 种事件类型 |
| **Codex CLI** | 进程检测 | ✅ 基础支持 | 运行/未运行 |

---

## 📊 多窗口追踪机制

### 如何追踪多个窗口？

当你同时打开多个 Claude Code / OpenCode / Codex 窗口时，Vibe Island 的追踪机制如下：

**Claude Code**：以**进程 PID** 作为会话标识。每个 Claude Code 进程有独立的 PID，Hook 系统会写入 `~/.vibe-island/sessions/<pid>.json`。`SessionFileWatcher` 使用 `DispatchSource` 同时监听目录下所有 JSON 文件的变化。

**OpenCode**：以 **session_id** 作为会话标识。插件/SSE/文件监控都会提取唯一的 session_id，并通过 PID 存活检测过滤已结束的会话。

**Codex CLI**：以**进程 PID** 作为会话标识。通过 `pgrep` 扫描所有 Codex 进程，每个进程对应一个会话。

### 灵动岛显示哪个窗口？

灵动岛**不支持手动窗口切换**，而是**自动显示最高优先级的会话**。系统会聚合所有工具的所有会话，按优先级排序后显示最需要你关注的那个。

举例：
- 窗口 A（Claude Code）：正在编码 → 优先级 3
- 窗口 B（OpenCode）：等待审批 → 优先级 0 ← **显示这个**
- 窗口 C（Codex）：运行中 → 优先级 5

当窗口 B 的审批完成后，灵动岛自动切换到窗口 A（编码状态）。

### 会话存活检测

系统通过以下机制确保会话状态的准确性：

1. **PID 存活检测** — 通过 `sysctl` 获取进程启动时间，区分 PID 复用
2. **心跳超时** — 长时间无事件的会话标记为陈旧
3. **自动清理** — 进程结束或会话完成后自动移除

---

## 📱 Widget 功能

Vibe Island 提供 macOS Widget，用于在桌面上快速查看 **API 额度信息**。

### Widget 功能一览

| 功能 | 说明 |
|------|------|
| **额度显示** | 显示单个或最多 2 个 API Provider 的剩余额度 |
| **环形进度条** | 直观展示已用/剩余百分比 |
| **平台选择** | 支持选择显示特定平台（MIMO/Kimi/MiniMax/智谱/火山方舟/全部） |
| **定时刷新** | 每 5 分钟自动刷新额度数据 |

### Widget 与主应用的关系

**Widget 和灵动岛是相互独立的功能模块**：

- **Widget** → 专注于 **API 额度**监控，数据来源是 `SharedDefaults`（App Group 共享存储）
- **灵动岛** → 专注于 **AI 工具运行状态**监控，数据来源是 Hook/插件/进程检测

Widget **不会**显示会话状态、宠物动画或声音提醒等灵动岛功能。它是独立的额度快捷查看器。

### Widget 尺寸

| 尺寸 | 显示内容 |
|------|---------|
| **Small** | 单个 Provider 的额度（名称 + 环形图 + 剩余量） |
| **Medium** | 最多 2 个 Provider 并排显示 |

---

## 🛠️ 开发

### 技术栈

- **Swift 6.0** - 并发安全
- **SwiftUI** - UI 框架
- **@Observable** - 状态管理
- **DispatchSource** - 文件监听
- **NSSound / AVAudioPlayer** - 声音播放
- **WidgetKit** - macOS Widget

### 架构模式

- MVVM + @Observable
- 单例服务（@MainActor）
- 依赖注入（.environment）

### 代码规范

- 中文注释
- MARK 分组
- Swift 6 并发安全

---

## 📝 待办事项

- [ ] 添加自定义声音文件
- [ ] 国际化支持（英文翻译）
- [ ] App Icon 优化
- [ ] 首次启动引导
- [ ] 窗口切换追踪 UI（可选）

---

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

---

## 🙏 致谢

- [cctop](https://github.com/nicholasgubb/cctop) - 参考其 Hook 系统设计
- [claude-buddy](https://github.com/claude-buddy) - 像素宠物灵感来源

---

## 📮 反馈

如有问题或建议，请提 Issue 或 PR。

---

**Made with ❤️ by Vibe Island Team**
