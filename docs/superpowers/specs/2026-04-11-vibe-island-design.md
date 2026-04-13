# Vibe Island — 设计文档 v4

> 项目重命名自 LLM Quota Island，核心方向从"API余额监控"转向"AI会话状态感知与氛围陪伴"。

## 1. 项目概述

> macOS Dynamic Island 风格浮动 HUD，通过 AI Coding Agent 的 Hook 系统实时感知会话状态，以**像素宠物 + 颜色指示 + 声音提醒**的方式，让开发者在 vibe coding 时不错过任何重要事件。

**核心痛点**：开发者给 AI agent 发任务后切去做别的事 → AI 需要审批/完成任务/上下文压缩 → 没注意就一直等，浪费时间。

**目标用户**：使用 Claude Code / OpenCode / Codex 等 AI coding 工具的开发者
**目标系统**：macOS 14+ (Sonoma)
**技术栈**：Swift 6 + SwiftUI + NSPanel + 文件+DispatchSource

---

## 1.5 技术验证状态

> 基于 GitHub 开源项目深度调研（两轮），识别每个技术点的可复用实现，避免从零开始。

**验证结论：核心技术点均有成熟开源参考，但存在 6 个高不确定性技术点需在实际开发前验证（Phase 0）。**

| 模块 | 参考项目 | 文件 | 直接复用度 | 验证状态 |
|------|----------|------|-----------|---------|
| Hook 事件接收 | cc-status-bar | `HookCommand.swift`, `HookEvent.swift` | 90% — 直接移植为 Swift | ⚠️ 需实际捕获验证 |
| Hook 自动安装 | cc-status-bar | `SetupManager` | 80% — 参考逻辑重写 | ✅ 可直接参考 |
| 文件监听通信 | cc-status-bar | `SessionObserver.swift` | 85% — 直接参考 | ⚠️ 需高频测试 |
| NSPanel 灵动岛 | Lyrisland | `DynamicIslandPanel.swift` | 95% — 直接复用 | ✅ 可直接参考 |
| 像素宠物 | claude-buddy | `pets.js` | 70% — 数据复用，渲染需重写 | ⚠️ 需原型验证 |
| Codex 监控 | cc-status-bar | `CodexObserver.swift` | 80% — 直接参考 | ✅ 可直接参考 |
| OpenCode 监控 | cctop + opencode-monitor | Plugin Hook + SSE | 75% — 四级降级方案 | ⚠️ 需三项验证 |
| 声音提醒 | 无 | — | 100% — 用 NSSound 即可 | ✅ 无风险 |

**总体可复用度：约 78%**，核心技术点均有成熟参考，但 Phase 0 技术验证必须在开发前完成。

### Phase 0 技术验证任务（前置条件）

以下 6 个高不确定性技术点必须在 Phase 1 开发前验证：

| # | 验证项 | 风险等级 | 验证方法 |
|---|--------|---------|---------|
| 0.1 | OpenCode Plugin Hook 实际可用性 | 🔴 高 | 克隆 cctop，实际运行测试 |
| 0.2 | OpenCode Session 文件格式 | 🔴 高 | 本地安装 OpenCode，检查实际文件 |
| 0.3 | OpenCode SSE 事件格式和稳定性 | 🔴 高 | 启动 serve，捕获实际事件流 |
| 0.4 | 像素宠物 Swift Canvas 渲染性能 | 🔴 高 | 实现原型，测试帧率 |
| 0.5 | Claude Code Hook stdin JSON 字段 | 🟡 中 | 实际运行 hook，捕获 12 种事件 |
| 0.6 | DispatchSource 文件监听可靠性 | 🟡 中 | 高频写入测试，验证防抖参数 |

详细评估：`docs/superpowers/specs/2026-04-13-technical-uncertainty-assessment.md`

---

## 2. 竞品深度对比

### 2.1 竞品总览

| 维度 | claude-buddy | cc-status-bar | cctop | Vibe Island (我们) |
|------|-------------|---------------|-------|-------------------|
| **仓库** | handsome-rich/claude-buddy | usedhonda/cc-status-bar | st0012/cctop | twmissingu/vibe-island |
| **技术栈** | Electron 35 + Express + WebSocket | Swift SPM (swift-tools-version 5.9) | Swift + JS Plugin | Swift 6 + SwiftUI + NSPanel |
| **平台** | 仅 Windows 10/11 | macOS 13+ | macOS 13.0+ | macOS 14+ |
| **Stars** | 7 (单日冲刺项目) | 77 (持续更新) | 70 (活跃) | N/A |
| **OpenCode 支持** | ❌ | ❌ | ✅ | ✅ |
| **活跃度** | 低维护/休眠 | 中等活跃 | 活跃 | 开发中 |

### 2.2 数据联动方案对比

| 维度 | claude-buddy | cc-status-bar | cctop | Vibe Island |
|------|-------------|---------------|-------|-------------|
| **Claude Code 通信** | curl POST → Express HTTP → WebSocket → UI | Hook CLI → 写 JSON → DispatchSource → UI | - | Hook CLI → 写 JSON → DispatchSource → UI |
| **OpenCode 通信** | - | - | Plugin Hook → 写 JSON → FileWatcher → UI | Plugin Hook → 写 JSON → DispatchSource → UI |
| **Hook 配置** | 自动写入 `~/.claude/settings.json` | 自动写入 `~/.claude/settings.json` | 手动安装 JS 插件 | 自动 + 手动（提供安装脚本） |
| **降级策略** | curl 重定向 /dev/null | CLI 写文件，App 未启动无副作用 | 文件监听降级 | 四级降级架构 |
| **Hook 事件数** | 9 种 | 6 种 | 3-5 种 | 预计 12 种（全量覆盖） |

**claude-buddy 的 Hook 实现细节**：
- 使用 command 类型 hook（非 http 类型），避免 Dashboard 未启动时返回 502
- 每个 hook 是一个 curl 命令，POST JSON 到 `http://127.0.0.1:13120/sessions/event`
- Express 端点解析 hook_event_name，更新 session Map，通过 WebSocket 广播
- 监听事件：SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, Notification, Stop, SessionEnd

**cc-status-bar 的 Hook 实现细节**：
- Hook 命令格式：`"/path/to/CCStatusBar" hook <EventName>`
- 每个 hook 触发时，Claude Code 通过 stdin 发送 JSON 数据
- 应用接收事件后写入 `~/Library/Application Support/CCStatusBar/sessions.json`
- 主应用通过 DispatchSourceFileSystemObject 实时检测文件变化
- 自动创建符号链接 `~/Library/Application Support/CCStatusBar/bin/CCStatusBar` → 应用可执行文件
- 非破坏性更新：保持其他工具的 hooks 不变

### 2.3 功能对比

| 功能 | claude-buddy | cc-status-bar | cctop | Vibe Island |
|------|-------------|---------------|-------|-------------|
| **灵动岛** | Electron 窗口模拟 (280×48 药丸) | 无 | ✅ 原生 NSPanel | ✅ 原生 NSPanel |
| **像素宠物** | 14 只，gacha 抽卡系统 | 无 | 无 | ✅ 8 只 + 进化系统 |
| **声音提醒** | ❌ 未实现 | 仅有警报 SoundPlayer | ❌ | ✅ 全状态提示音 |
| **上下文压缩感知** | ❌ | ❌ | ❌ | ✅ PreCompact hook (独家) |
| **多工具支持** | 仅 Claude Code | Claude + Codex | Claude + OpenCode | Claude + OpenCode + Codex |
| **权限审批** | 仅显示 waiting 状态 | 无 | 无 | 计划内 |
| **会话统计** | ❌ | 有（总时长等） | 有 | 计划内 |
| **OpenCode 监控** | ❌ | ❌ | ✅ Plugin Hook | ✅ 四级降级 |

### 2.4 claude-buddy 像素宠物系统（参考）

- **帧数据格式**：14列 × 10行像素网格，hex 字符串编码，0=透明，1-9=调色板索引，行用 `|` 分隔
- **调色板**：每个宠物独立 palette，如 `{ 1:'#FFD700', 2:'#B8960F', 3:'#1a1a1a' }`
- **动画状态**：idle (2帧, 800ms), running (2帧, 250ms), waiting (2帧, 600ms)
- **总计**：14只 × 3状态 × 2帧 = 84个独立帧
- **Gacha 概率**：基础掉落率 15%，会话 >10min +10%，>30min +10%（最高 35%）
- **稀有度**：N(68.9%), R(25%), SR(5%), SSR(1%), UR(0.1%)

### 2.5 cc-status-bar 关键设计（参考）

- **分层架构**：App / CLI / Models / Services / Views
- **响应式编程**：Combine 框架，@Published + ObservableObject
- **状态级别**：🟢 运行中 / 🔴 需要权限（最高优先级）/ 🟡 等待用户输入 / ⚪ 空闲
- **Hook 自动安装**：SetupManager 首次运行自动配置，检测缺失时自动修复
- **Codex 集成**：已注册 Codex hook 支持
- **终端支持**：Ghostty+tmux、iTerm2、VS Code/Cursor/Windsurf

### 2.6 我们的核心差异化

| 差异点 | 说明 | 价值 |
|--------|------|------|
| **原生 Swift** | claude-buddy 是 Electron，吃内存/卡顿/无 macOS 原生集成 | 性能和视觉体验碾压 |
| **真原生灵动岛** | claude-buddy 用 BrowserWindow 模拟，我们用 NSPanel 直接浮动在所有窗口之上 | 支持 macOS 原生模糊/动画 |
| **上下文压缩感知** | 竞品都没有监听 PreCompact 事件 | vibe coder 最需要的功能之一 |
| **声音提醒** | 两家都没有实现 | 切到其他页面时唯一兜底提醒 |
| **多工具统一入口** | claude-buddy 只支持 Claude Code，cc-status-bar 支持 Claude+Codex，cctop 支持 Claude+OpenCode | 全量覆盖 |
| **OpenCode 四级降级** | cctop 仅 Plugin Hook，我们有 4 层降级确保各种场景可用 | 更高的可用性 |

---

## 3. 核心功能

### 3.1 AI 会话状态感知

**数据来源**：Claude Code Hooks（12 种事件）

| Hook 事件 | 触发时机 | 灵动岛表现 | 声音 |
|-----------|---------|-----------|------|
| `SessionStart` | 会话开始 | 🚀 宠物苏醒动画，白色边框 | 无 |
| `UserPromptSubmit` | 用户提交 prompt | 💬 宠物活跃，绿色边框 | 无 |
| `PreToolUse` | 工具调用前 | 🔧 宠物思考状态 | 无 |
| `PostToolUse` | 工具完成 | ✅ 宠物点头 | 无 |
| `PostToolUseFailure` | 工具失败 | ❌ 宠物慌张 + 红色闪烁 | 警告音 |
| `PermissionRequest` | **需要审批** | 🔐 **黄色闪烁 + 宠物举手** | **短促叮声（2秒重复）** |
| `Notification` | 用户交互提醒 | 🔔 宠物弹跳 | 轻柔提示音 |
| `Stop` | **响应完成** | 🛑 **绿色闪烁 + 宠物庆祝** | **清脆完成音** |
| `PreCompact` | **上下文压缩** | 📦 **橙色闪烁 + 宠物背包** | **轻柔提示音** |
| `SessionEnd` | 会话结束 | 🏁 宠物休息，白色边框 | 无 |
| `SubagentStart` | 子 agent 启动 | 🟢 宠物分身 | 无 |
| `SubagentStop` | 子 agent 结束 | 👥 宠物合体 | 无 |

### 3.2 灵动岛视觉反馈

**收起态颜色编码**：
```
🟢 绿色边框 = 正常运行（UserPromptSubmit, PreToolUse, PostToolUse）
🟡 黄色边框 = 需要审批（PermissionRequest）— 最高优先级，闪烁
🔴 红色边框 = 出错（PostToolUseFailure）
🟠 橙色边框 = 上下文即将压缩（PreCompact）
⚪ 白色边框 = 空闲（SessionStart, SessionEnd）
```

**展开态详情**：
- 当前会话状态 + 状态持续时间
- 上下文使用率进度条（接近压缩时变色）
- 今日会话数 / Token 消耗统计
- 活跃会话列表（多工具聚合）

### 3.3 声音提醒

| 事件 | 声音 | 行为 |
|------|------|------|
| 需要审批 | 短促叮声 | 2秒重复直到用户确认 |
| 任务完成 | 清脆完成音 | 播放一次 |
| 出错 | 警告音 | 播放一次 |
| 上下文压缩 | 轻柔提示音 | 播放一次 |

### 3.4 像素宠物状态映射

```
idle        → 2帧呼吸循环（800ms间隔）
thinking    → 眉毛上挑 + 眼睛闪烁
coding      → 敲键盘动作（250ms间隔）
waiting     → 举手 + 头顶问号气泡（600ms间隔）
celebrating → 跳跃 + 撒花
error       → 倒地 + 红色叹号
compacting  → 背包（上下文在压缩）
sleeping    → zzz（会话结束/空闲）
```

**进化系统**：基于 coding 时长积累 XP，宠物可进化出新外观（相比 claude-buddy 的 gacha 抽卡，进化系统更有持续激励感）。

---

## 4. 技术架构

### 4.1 整体架构

```
VibeIslandKit (SPM 共享包)        ← 数据层，主 App 共享
├── Models/                      ← SessionEvent, SessionState, ToolStatus
├── CLI/                         ← vibe-island 命令行工具（hook 入口）
├── Monitor/                     ← 进程监控 + session 文件监控
├── Observer/                    ← DispatchSource 文件监听 + 防抖动
└── Storage/                     ← 配置持久化

VibeIsland (主 App)              ← UI 层
├── App/                         ← 入口 + AppDelegate
├── Window/                      ← DynamicIslandPanel + IslandState
├── State/                       ← StateManager 状态机
├── Pet/                         ← PetEngine + SpriteRenderer + PetData
├── Sound/                       ← SoundManager
├── Theme/                       ← ThemeManager + PixelTheme + GlassTheme
├── Views/                       ← IslandView + SettingsView + 各子视图
└── Resources/                   ← 字体 + 精灵数据 + 音效
```

**数据流**：
```
Claude Code ──hooks──→ vibe-island CLI ──写JSON文件──→ Vibe Island App (DispatchSource监听)
                                                          ├── DynamicIslandPanel (颜色/动画)
                                                          ├── StateManager (状态机)
                                                          ├── PetEngine (宠物动画)
                                                          ├── SoundManager (提示音)
                                                          └── ThemeManager (主题)

OpenCode ──Plugin Hook──→ vibe-island CLI ──写JSON文件──→ 同上
       ──SSE (serve)──→ SSE Client ──解析事件──→ 同上
       ──文件监控──→ File Observer ──解析JSON──→ 同上
       ──进程检测──→ Process Check ──基础状态──→ 同上

Codex ──session.jsonl──→ SessionFileWatcher ──────────→ 同上
```

### 4.2 数据联动方案（核心技术路径）

#### Claude Code（主要数据源，Hook 系统）

参考 cc-status-bar 的成功实现（`HookCommand.swift` + `HookEvent.swift` + `SessionObserver.swift`）：

```swift
// Hook 配置自动写入 ~/.claude/settings.json
// 参考 cc-status-bar SetupManager 的非破坏性更新策略
{
  "hooks": {
    "PermissionRequest": [{
      "hooks": [{
        "type": "command",
        "command": "/path/to/vibe-island hook PermissionRequest"
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "/path/to/vibe-island hook Stop"
      }]
    }],
    // ... 其余 10 种事件
  }
}
```

**通信机制**（参考 cc-status-bar `SessionObserver.swift`，已在生产环境验证）：
- CLI 工具 `vibe-island` 接收 hook 事件（stdin JSON）
- 写入 JSON 文件：`~/Library/Application Support/VibeIsland/events.json`
- 主 App 用 DispatchSourceFileSystemObject 监听文件变化 + 防抖动 + 降级轮询
- 非阻塞：App 未启动时 CLI 写文件即返回，不阻塞 hook

**DispatchSource 监听流程**：
1. `open(.EVTONLY)` 打开文件描述符
2. `DispatchSource.makeFileSystemObjectSource` 监听 `.write/.rename/.delete` 事件
3. 文件变化时触发 `handleFileChange()`，读取最新状态
4. 定时轮询兜底（DispatchSource 失效时降级）

**Hook 自动安装**（参考 cc-status-bar SetupManager）：
1. 首次启动自动创建符号链接
2. 备份并修改 `~/.claude/settings.json`
3. 非破坏性更新：保持其他工具的 hooks 不变
4. 应用移动检测：自动更新符号链接
5. 修复机制：检测 hooks 缺失时自动修复

#### OpenCode / Codex（辅助数据源）

| 工具 | 检测方式 | 参考项目 | 实现方案 |
|------|---------|---------|---------|
| Claude Code | Hooks 系统（12种事件） | cc-status-bar `HookCommand.swift` + hooks-mastery | 自动安装 + 文件监听 |
| OpenCode | Plugin Hook + SSE + 文件监控 + 进程检测 | cctop + opencode-monitor | 四级降级架构 |
| Codex | `pgrep` 进程监控 + cwd 匹配 + 3级缓存 | cc-status-bar `CodexObserver.swift` | 进程监控 + 文件解析 |

**OpenCode 四级降级实现**：

```swift
// Level 1: Plugin Hook 方案
// 安装插件到 ~/.config/opencode/plugins/vibe-island.js
// 插件拦截事件 → 调用 CLI → 写入 JSON 文件
// 文件路径：~/.vibe-island/opencode-sessions/{sessionID}.json

// Level 2: SSE 方案
// 检测 opencode serve 模式是否运行
// 连接 http://localhost:4040/global/event
// 解析 SSE 事件流

// Level 3: 文件监控方案
// 监控 ~/.local/share/opencode/storage/
// DispatchSource 监听文件变化 + 定期轮询

// Level 4: 进程检测方案
// pgrep -f opencode
// 仅显示基础运行状态
```

**OpenCode 插件实现**（参考 cctop）：

```javascript
// ~/.config/opencode/plugins/vibe-island.js
export const name = "vibe-island"

export async function init(input) {
  const { event, config, $ } = input
  
  // 订阅 session.status 事件
  input.event.subscribe("session.status", async (event) => {
    const sessionID = event.properties.sessionID
    const status = event.properties.status
    
    // 调用统一 CLI
    await $`vibe-island hook OpenCodeSessionStatus \
      --session-id ${sessionID} \
      --status ${status} \
      --cwd ${config.cwd}`
  })
}
```

**OpenCode 一键安装脚本**：

```bash
#!/bin/bash
# 安装 OpenCode 监控插件
PLUGIN_DIR="$HOME/.config/opencode/plugins"
mkdir -p "$PLUGIN_DIR"
cp vibe-island-opencode-plugin.js "$PLUGIN_DIR/vibe-island.js"
echo "✅ OpenCode 监控插件已安装"
```

### 4.3 数据模型

```swift
// 会话事件（从 Hook 接收）
struct SessionEvent: Codable, Sendable {
    let tool: ToolType           // .claudeCode, .openCode, .codex
    let eventType: HookEventType // 12种事件类型
    let sessionID: String?
    let timestamp: Date
    let payload: [String: String]? // 额外数据
}

// 工具类型
enum ToolType: String, Codable, CaseIterable {
    case claudeCode = "claude-code"
    case openCode = "open-code"
    case codex
}

// Hook 事件类型（12 种）
enum HookEventType: String, Codable {
    case sessionStart, sessionEnd
    case userPromptSubmit
    case preToolUse, postToolUse, postToolUseFailure
    case permissionRequest
    case notification
    case stop
    case preCompact
    case subagentStart, subagentStop
}

// 岛屿状态（UI 驱动，5 种）
// 注意：这是 SessionState（7 种 AI 状态）到 IslandStatus 的映射
enum IslandStatus: String, Codable {
    case idle        // ⚪ 白色，空闲（对应：idle, sleeping）
    case running     // 🟢 绿色，正常运行（对应：thinking, coding, completed）
    case waiting     // 🟡 黄色闪烁，需要审批（对应：waiting）
    case error       // 🔴 红色，出错（对应：error）
    case compacting  // 🟠 橙色，上下文压缩（对应：compacting）
}

// 会话状态（AI 内部状态，7 种）
enum SessionState: String, Codable {
    case idle        // 空闲，等待输入
    case thinking    // 思考中，处理 prompt
    case coding      // 编码中，调用工具
    case waiting     // 等待用户审批
    case completed   // 任务完成
    case error       // 出错/中止
    case compacting  // 上下文压缩中
}

// SessionState → IslandStatus 映射
extension SessionState {
    var islandStatus: IslandStatus {
        switch self {
        case .idle: .idle
        case .thinking, .coding, .completed: .running
        case .waiting: .waiting
        case .error: .error
        case .compacting: .compacting
        }
    }
}

// 会话状态
struct SessionStateModel: Codable, Sendable {
    let sessionID: String
    let tool: ToolType
    var state: SessionState        // AI 内部状态
    var islandStatus: IslandStatus // UI 显示状态（自动映射）
    var projectName: String?
    var startedAt: Date
    var lastEventAt: Date
    var contextUsagePercent: Double? // 0.0~1.0
}
```

### 4.4 核心模块

|| 模块 | 职责 | 参考 |
||------|------|------|
|| `VibeIslandCLI` | 命令行工具，接收 hook 事件，写入 JSON 文件 | cc-status-bar `HookCommand.swift` |
|| `SessionObserver` | DispatchSource 文件监听 + 防抖动 + 降级轮询 | cc-status-bar `SessionObserver.swift` |
|| `StateManager` | 会话状态机，聚合多工具状态，决定灵动岛表现 | cc-status-bar SessionStore |
|| `SessionMonitor` | 进程监控 + session 文件监控（OpenCode/Codex） | cc-status-bar `CodexObserver.swift` |
|| `DynamicIslandPanel` | 浮动窗口，根据状态改变颜色/大小/动画 | Lyrisland `DynamicIslandPanel.swift` |
|| `PetEngine` | 宠物状态映射 + 帧动画调度 | claude-buddy `pets.js` |
|| `SpriteRenderer` | hex 帧数据 → SwiftUI Canvas 渲染 | claude-buddy hex 格式 |
|| `SoundManager` | 状态变化时播放提示音（NSSound 系统音效 + AVAudioPlayer 自定义音效） | NSSound 用于系统提示音，AVAudioPlayer 用于宠物相关音效 |
|| `HookInstaller` | 自动安装/卸载 Claude Code hooks | cc-status-bar `SetupManager` |

---

## 5. 开源资产复用

| 模块 | 参考项目 | 许可证 | 复用方式 |
|------|----------|--------|----------|
| Dynamic Island 窗口 | [EurFelux/Lyrisland](https://github.com/EurFelux/Lyrisland) | MIT | 参考 NSPanel 无边框、statusBar+1 级别、透明背景、多桌面常驻 |
| Hook 配置 + 自动安装 | [usedhonda/cc-status-bar](https://github.com/usedhonda/cc-status-bar) | MIT | 参考 SetupManager 自动配置、非破坏性更新、符号链接管理 |
| 像素宠物精灵 | [handsome-rich/claude-buddy](https://github.com/handsome-rich/claude-buddy) | MIT | 复用 hex 编码帧格式和 14 款宠物 sprite 数据，移植为 Swift 渲染 |
| Hook 事件处理 | [handsome-rich/claude-buddy](https://github.com/handsome-rich/claude-buddy) | MIT | 参考 9 种事件的 curl→Express→WS 流程，改为文件+DispatchSource |
| OpenCode Plugin Hook | [st0012/cctop](https://github.com/st0012/cctop) | MIT | 参考插件架构、Hook CLI 实现、文件监听机制 |
| OpenCode SSE | OpenCode 官方 SDK | - | 参考 TypeScript SDK 的事件订阅和解析 |
| OpenCode 监控 | [actualyze-ai/opencode-monitor](https://github.com/actualyze-ai/opencode-monitor) | - | 参考 WebSocket 推送架构、TUI 状态展示 |
| 多工具支持架构 | [yelog/vibebar](https://github.com/yelog/vibebar) | — | 参考 session 文件解析、进程监控模式 |
| SPM 共享包架构 | [niederme/ai-quota](https://github.com/niederme/ai-quota) | — | 参考 Models/Networking/Storage/Widgets 分层 |
| 像素字体 | Press Start 2P (Google Fonts) | OFL | 像素风格主题的数字/文字渲染 |

---

## 6. 开发阶段

### Phase 1：Hook 系统 + 状态感知（核心验证）
- CLI 工具 `vibe-island hook <EventType>`（接收 stdin JSON）
- 文件+DispatchSource 通信（CLI → 主 App）
- Claude Code hooks 自动配置（参考 cc-status-bar SetupManager）
- StateManager 状态机：事件 → IslandStatus 映射
- DynamicIslandPanel 颜色变化（绿/黄/红/橙/白）
- **里程碑**：Claude Code 需要审批时灵动岛变黄 + 提示音

### Phase 2：像素宠物 + 动画
- 帧数据转换（claude-buddy hex → Swift）
- 8 款宠物数据移植
- PetEngine 状态机（idle/thinking/coding/waiting/celebrating/error/compacting/sleeping）
- SpriteRenderer 渲染
- **里程碑**：宠物实时响应 Claude Code 状态变化

### Phase 3：声音 + 上下文感知
- SoundManager（AVAudioPlayer）
- 4 种提示音（审批/完成/错误/压缩）
- PreCompact 事件处理 + 上下文使用率显示
- **里程碑**：切到其他页面时声音提醒生效

### Phase 4：多工具支持
- OpenCode Plugin Hook 实现（参考 cctop）
- OpenCode 一键安装脚本
- OpenCode SSE 客户端（serve 模式备选）
- OpenCode 文件监控降级方案
- OpenCode 进程检测兜底
- Codex session.jsonl 解析
- 多工具状态聚合（StateManager 扩展）
- **里程碑**：同时监控 3 个工具的会话，四级降级自动切换

### Phase 5：设置 + 打磨 + 发布
- SettingsView（hook 安装/卸载、声音开关、宠物选择、主题切换）
- PixelTheme + GlassTheme 双主题
- App Icon + README + MIT LICENSE
- GitHub Release
- **里程碑**：v1.0 开源发布

---

## 7. 项目文件结构

```
vibe-island/
├── VibeIsland.xcodeproj
├── project.yml                      ← XcodeGen 配置
│
├── Packages/
│   └── LLMQuotaKit/                 ← SPM 共享包
│       ├── Package.swift
│       └── Sources/LLMQuotaKit/
│           ├── Models/              ← QuotaInfo, ProviderType, AppSettings
│           ├── Network/             ← NetworkClient, QuotaProvider 协议
│           └── Storage/             ← KeychainStorage, SharedDefaults
│
├── Sources/
│   └── VibeIsland/                  ← 主 App
│       ├── App/
│       │   ├── VibeIslandApp.swift      ← 入口 + NSPanel 初始化
│       │   ├── Info.plist
│       │   └── VibeIsland.entitlements
│       ├── Window/
│       │   ├── DynamicIslandPanel.swift ← 借鉴 Lyrisland
│       │   └── IslandState.swift        ← compact/expanded 状态
│       ├── ViewModel/
│       │   └── StateManager.swift       ← 核心状态管理（原 QuotaViewModel）
│       ├── Views/
│       │   ├── IslandView.swift         ← 主视图，切换 compact/expanded
│       │   ├── CompactIslandView.swift  ← 收起态
│       │   ├── ExpandedIslandView.swift ← 展开态
│       │   ├── SettingsView.swift       ← 设置面板
│       │   └── CircularGaugeView.swift  ← 环形进度条
│       └── Resources/               ← 资源文件
│
├── Widget/                          ← macOS Widget（未来扩展）
│   ├── LLMQuotaWidget.swift
│   ├── Provider/
│   └── Views/
│
├── docs/
│   └── superpowers/specs/
│       ├── 2026-04-11-task-plan.md
│       ├── 2026-04-11-tech-validation.md
│       ├── 2026-04-11-vibe-island-design.md
│       ├── 2026-04-13-technical-uncertainty-assessment.md
│       └── 2026-04-13-ui-design.md
│
├── VibeIsland.entitlements
├── LICENSE                          ← MIT
└── README.md
```

---

## 8. 技术选型总结

| 维度 | 选型 |
|------|------|
| 语言 | Swift 6.0 |
| UI 框架 | SwiftUI + AppKit (NSPanel) |
| 最低系统 | macOS 14 (Sonoma) |
| 通信 | 文件+DispatchSource (CLI → App) |
| 配置存储 | UserDefaults |
| Hook 配置 | 自动修改 `~/.claude/settings.json`（参考 cc-status-bar） |
| 共享数据层 | SPM 本地包 VibeIslandKit |
| 音频 | AVAudioPlayer |
| 像素帧格式 | hex 编码（兼容 claude-buddy） |
| 字体 | Press Start 2P (OFL) |
| 项目管理 | XcodeGen project.yml |
| 构建 | Xcode + SPM |
| 许可证 | MIT |
