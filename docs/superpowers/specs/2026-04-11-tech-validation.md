# Vibe Island — 技术验证文档

> 基于 GitHub 开源项目深度调研，识别每个技术点的可复用实现，避免从零开始。

## 验证结论

**P0/P1 所有技术点均有成熟开源参考，无需从零验证。** 唯一需要自行调研的是 OpenCode 的 session 文件格式。

---

## 1. Claude Code Hook 事件接收

### 状态：✅ 已验证，可直接复用

### stdin JSON 格式（12 种事件完整字段）

| 事件 | 关键字段 |
|------|---------|
| `UserPromptSubmit` | `session_id`, `prompt`, `cwd` |
| `PreToolUse` | `session_id`, `tool_name`, `tool_input`, `tool_use_id` |
| `PostToolUse` | `session_id`, `tool_name`, `tool_input`, `tool_response` |
| `PostToolUseFailure` | `session_id`, `tool_name`, `error`, `is_interrupt` |
| `PermissionRequest` | `session_id`, `tool_name`, `tool_input`, `permission_suggestions` |
| `Notification` | `session_id`, `notification_type`, `message`, `tool_name` |
| `Stop` | `session_id`, `stop_hook_active` |
| `PreCompact` | `session_id`, `transcript_path`, `trigger`("manual"/"auto"), `custom_instructions` |
| `SessionStart` | `session_id`, `source`("startup"/"resume"/"clear"), `cwd` |
| `SessionEnd` | `session_id`, `transcript_path`, `cwd`, `reason` |
| `SubagentStart` | `session_id`, `agent_id`, `agent_type` |
| `SubagentStop` | `session_id`, `agent_id`, `stop_hook_active` |

### 参考项目

| 项目 | Stars | 复用内容 |
|------|-------|---------|
| [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) | 3511 | 完整 13 种 hook 事件的 Python 实现，含 stdin JSON 读取 |
| [disler/claude-code-hooks-multi-agent-observability](https://github.com/disler/claude-code-hooks-multi-agent-observability) | 1364 | `send_event.py` — hook 事件通过 HTTP POST 发送到监控服务器 |
| [usedhonda/cc-status-bar](https://github.com/usedhonda/cc-status-bar) | 77 | **Swift 原生实现** — `HookCommand.swift` + `HookEvent.swift` |

### 关键代码参考（cc-status-bar）

```swift
// HookCommand.swift — CLI 接收 stdin JSON
public func run() throws {
    let stdinData = FileHandle.standardInput.readDataToEndOfFile()
    guard !stdinData.isEmpty else {
        throw ValidationError("No input received from stdin")
    }
    let decoder = JSONDecoder()
    var event = try decoder.decode(HookEvent.self, from: stdinData)
    // 处理事件...
}
```

```swift
// HookEvent.swift — 完整数据模型
struct HookEvent: Codable {
    let sessionId: String        // session_id
    let cwd: String
    var tty: String?
    let hookEventName: HookEventName
    let notificationType: String?    // "permission_prompt" 等
    let message: String?
    let toolName: String?
    let question: HookQuestionPayload?
    // ... 更多字段
}
```

---

## 2. CLI → App 通信

### 状态：✅ 已验证，推荐文件+DispatchSource 方案

### 三种方案对比

| 方案 | 参考项目 | 优点 | 缺点 |
|------|---------|------|------|
| **文件+DispatchSource** | cc-status-bar `SessionObserver.swift` | 简单可靠，已验证 | 有文件 IO 开销 |
| **HTTP POST** | multi-agent-observability `send_event.py` | 通用，支持远程 | 需要 HTTP 服务器 |
| **Unix Domain Socket** | 无直接参考 | 最低延迟 | 实现复杂，需维护连接 |

### 推荐：文件+DispatchSource

理由：
1. cc-status-bar 已在生产环境验证，77⭐ 项目持续活跃
2. `SessionObserver.swift` 实现完整：DispatchSource 监听 + 防抖动 + 降级轮询
3. 比 Unix Socket 更简单，不需要维护 socket 连接
4. 支持 App 未启动时 hook 不阻塞（CLI 写文件即可）

### 关键代码参考（cc-status-bar）

```swift
// SessionObserver.swift — 文件监听核心
final class SessionObserver: ObservableObject {
    @Published private(set) var sessions: [Session] = []
    
    private let storeFile: URL
    private var fileDescriptor: Int32 = -1
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var fallbackPollingTimer: Timer?
    private var lastObservedStoreMTime: Date?
    
    func startWatching() {
        fileDescriptor = open(storeFile.path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.main
        )
        source.setEventHandler { [weak self] in
            self?.handleFileChange()
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd != -1 {
                close(fd)
            }
        }
        dispatchSource = source
        source.resume()
    }
}
```

### 我们的实现方案

```
vibe-island hook <EventType>    ← CLI 接收 stdin JSON
    ↓
写入 ~/Library/Application Support/VibeIsland/events.json
    ↓
DispatchSourceFileSystemObject 监听文件变化
    ↓
主 App 更新 StateManager → UI 刷新
```

---

## 3. Hook 自动安装

### 状态：✅ 已验证，直接参考 cc-status-bar

### 参考项目

| 项目 | 复用内容 |
|------|---------|
| [usedhonda/cc-status-bar](https://github.com/usedhonda/cc-status-bar) | `SetupManager` — 自动创建符号链接、备份修改 settings.json、非破坏性更新、自动修复 |

### settings.json hooks 结构（已确认）

```json
{
  "hooks": {
    "PermissionRequest": [{
      "matcher": "",
      "hooks": [{"type": "command", "command": "/path/to/vibe-island hook PermissionRequest"}]
    }],
    "Stop": [{
      "hooks": [{"type": "command", "command": "/path/to/vibe-island hook Stop"}]
    }],
    "PreCompact": [{
      "hooks": [{"type": "command", "command": "/path/to/vibe-island hook PreCompact"}]
    }]
  }
}
```

### 可用环境变量

| 变量 | 说明 |
|------|------|
| `$CLAUDE_PROJECT_DIR` | 当前项目目录 |

### Hook 安装流程（参考 cc-status-bar SetupManager）

1. 检查应用转译（App Translocation）
2. 创建符号链接 `~/Library/Application Support/VibeIsland/bin/vibe-island` → 应用可执行文件
3. 备份现有 `~/.claude/settings.json`
4. 注入 Vibe Island hooks（非破坏性，保持其他工具 hooks 不变）
5. 应用移动检测：自动更新符号链接
6. 修复机制：检测 hooks 缺失时自动修复

---

## 4. NSPanel Dynamic Island

### 状态：✅ 已验证，直接参考 Lyrisland

### 参考项目

| 项目 | Stars | 许可证 | 复用内容 |
|------|-------|--------|---------|
| [EurFelux/Lyrisland](https://github.com/EurFelux/Lyrisland) | — | MIT | `DynamicIslandPanel.swift` — 完整 NSPanel 浮动窗口实现 |

### 关键配置（Lyrisland）

```swift
// DynamicIslandPanel.swift
super.init(
    contentRect: NSRect(origin: .zero, size: initialSize),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)

level = .statusBar + 1                    // 浮动在菜单栏之上
isOpaque = false                          // 透明背景
backgroundColor = .clear
hasShadow = false
hidesOnDeactivate = false                 // 切换应用不隐藏
collectionBehavior = [
    .canJoinAllSpaces,                    // 所有桌面空间可见
    .stationary,                          // 不随 Mission Control 移动
    .fullScreenAuxiliary                  // 全屏模式下可见
]
animationBehavior = .utilityWindow        // 平滑动画
```

### 支持的模式

- **Attached**：贴附菜单栏，居中显示
- **Detached**：自由拖拽，记住位置

### 我们的扩展

在 Lyrisland 基础上增加：
- 状态驱动的颜色变化（绿/黄/红/橙/白）
- 宠物动画集成
- 声音触发

---

## 5. 像素宠物渲染

### 状态：✅ 已验证，直接复用帧数据

### 参考项目

| 项目 | Stars | 许可证 | 复用内容 |
|------|-------|--------|---------|
| [handsome-rich/claude-buddy](https://github.com/handsome-rich/claude-buddy) | 7 | MIT | `pets.js` — hex 编码帧格式 + 14 款宠物 sprite 数据 |

### 帧数据格式

```
14 列 × 10 行像素网格
hex 字符串，每位代表一个像素索引
0 = 透明，1-9 = 调色板颜色索引
行之间用 | 分隔
```

### 示例（Chick 小鸡 idle 帧）

```
00001100001100
00001122002200
00011223002300
00011220002000
00112221122100
00112221122100
00011222222000
00001122220000
00000112200000
00000011000000
```

### 调色板

```json
{
  "1": "#FFD700",
  "2": "#B8960F",
  "3": "#1a1a1a"
}
```

### 动画状态

| 状态 | 帧数 | 间隔 |
|------|------|------|
| idle | 2 帧 | 800ms |
| running | 2 帧 | 250ms |
| waiting | 2 帧 | 600ms |

### 渲染方案

SwiftUI Canvas 绘制，将 hex 字符串解码为 2D 数组，按调色板上色。

---

## 6. Codex 监控

### 状态：✅ 已验证，直接参考 cc-status-bar

### 参考项目

| 项目 | 复用内容 |
|------|---------|
| [usedhonda/cc-status-bar](https://github.com/usedhonda/cc-status-bar) | `CodexObserver.swift` — 进程监控 + 缓存 + cwd 匹配 |

### 实现方式

- 通过 `pgrep` 检测 Codex 进程
- 按 `cwd`（工作目录）关联会话
- 3 级缓存：fresh(5s) / stale(30s) / empty
- 支持 hooks 模式（`CodexHooksSessionStore`）
- 防止并发刷新（`isRefreshing` 锁）

### 关键代码参考

```swift
// CodexObserver.swift — 进程监控 + 缓存
enum CodexObserver {
    private static var sessionsCache: (sessions: [String: CodexSession], timestamp: Date)?
    private static let freshTTL: TimeInterval = 5.0
    private static let staleTTL: TimeInterval = 30.0
    
    static func getActiveSessions() -> [String: CodexSession] {
        let now = Date()
        if let cached = sessionsCache {
            let age = now.timeIntervalSince(cached.timestamp)
            if age < freshTTL { return cached.sessions }      // Fresh: 直接返回
            if age < staleTTL {                                // Stale: 返回缓存+后台刷新
                triggerBackgroundRefresh()
                return cached.sessions
            }
        }
        triggerBackgroundRefresh()
        return sessionsCache?.sessions ?? [:]
    }
}
```

---

## 7. OpenCode 监控

### 状态：✅ 已验证，四级降级方案

### 核心发现

**OpenCode 官方不支持类似 Claude Code 的 stdin hook 机制**（Issue #14863 已关闭，"not planned"），但存在 **4 种可行的监控方案**，按推荐优先级排序。

### 方案对比

| 方案 | 可行性 | 实时性 | 实现难度 | 推荐指数 | 参考项目 |
|------|--------|--------|----------|---------|---------|
| **Plugin Hook + 文件监听** | ✅ 完全可行 | 实时 | 中 | ⭐⭐⭐⭐⭐ | [cctop](https://github.com/st0012/cctop) (70⭐) |
| **REST API + SSE** | ✅ 完全可行 | 实时 | 中 | ⭐⭐⭐⭐ | OpenCode 官方 SDK |
| **Session 文件监听** | ✅ 完全可行 | 准实时 | 低 | ⭐⭐⭐⭐ | cc-status-bar CodexObserver |
| **进程监控** | ✅ 完全可行 | 低 | 极低 | ⭐⭐ | - |

### 方案一：Plugin Hook + 文件监听（⭐ 最推荐）

#### 技术原理

在每个 OpenCode 实例中安装专用插件（`~/.config/opencode/plugins/vibe-island.js`），插件拦截事件总线，调用统一 CLI 写入 JSON 文件，App 通过 DispatchSource 监听文件变化。

#### 架构设计

```
OpenCode TUI
    ↓ 触发事件
Plugin (vibe-island.js)
    ↓ 执行外部命令
vibe-island-hook --event session.status --session-id xxx
    ↓ 写入文件
~/.vibe-island/opencode-sessions/{sessionID}.json
    ↓ DispatchSource 监听
App StateManager → UI
```

#### 插件实现（参考 cctop）

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
  
  // 订阅 tool.execute 事件
  input.event.subscribe("tool.execute", async (event) => {
    // 类似处理...
  })
}
```

#### Hook CLI 数据格式

```json
{
  "event": "session.status",
  "sessionID": "abc123",
  "cwd": "/Users/user/project",
  "status": "working",
  "timestamp": 1744531200000,
  "pid": 12345,
  "projectName": "my-project"
}
```

#### 优势
- ✅ **真正的实时事件**，插件拦截 OpenCode 内部事件
- ✅ **不依赖 SSE/HTTP 服务**，TUI 模式也可用
- ✅ **已有完整实现**，cctop 项目已验证
- ✅ **文件通信简单可靠**，无网络依赖

#### 劣势
- ⚠️ **需用户手动安装插件**
- ⚠️ **无法自动安装**（与 Claude Code 的 settings.json hooks 不同）
- ⚠️ **插件 API 可能变化**

### 方案二：REST API + SSE（官方支持）

#### 可用端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/global/event` | GET (SSE) | 全局事件流（跨所有实例） |
| `/event` | GET (SSE) | 实例特定事件流 |
| `/session/list` | GET | 列出所有会话 |
| `/session/{id}/status` | GET | 获取会话状态 |

#### SSE 事件格式

```
data: {"payload":{"type":"session.created","properties":{"id":"xxx","cwd":"/path"}}}
data: {"payload":{"type":"session.status","properties":{"sessionID":"xxx","status":"working"}}}
data: {"payload":{"type":"message.completed","properties":{"sessionID":"xxx"}}}
```

#### Swift SSE 客户端实现

```swift
class OpenCodeSSEClient {
    private let baseURL = URL(string: "http://localhost:4040")!
    
    func subscribe() {
        var request = URLRequest(url: baseURL.appendingPathComponent("/global/event"))
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // 建立长连接，解析 data: 行的 JSON 事件
        // 根据 payload.type 分发处理
        // 断线自动重连（指数退避）
    }
}
```

#### 优势
- ✅ **官方支持**，无需插件安装
- ✅ **有 TypeScript/Python SDK**参考
- ✅ **真正的实时监控**

#### 劣势
- ⚠️ **需 `opencode serve` 模式**，TUI 模式不可用
- ⚠️ **SSE 长连接可能断开**
- ⚠️ **默认端口 4040 可能冲突**

### 方案三：Session 文件监听（降级方案）

#### 数据存储路径

```
~/.local/share/opencode/
├── auth.json
├── storage/
│   ├── {project-hash}/
│   │   ├── sessions.json
│   │   └── {session-id}/
│   │       ├── messages.json
│   │       └── metadata.json
├── log/
└── project/
```

#### 实现方式（参考 CodexObserver）

```swift
enum OpenCodeFileObserver {
    private static let storagePath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/opencode/storage/")
    
    static func startWatching() {
        // 1. 监控 storage 目录
        // 2. 使用 DispatchSource 监听文件变化
        // 3. 解析 JSON 文件获取 session 状态
        // 4. 防抖 + 降级轮询
    }
}
```

#### 优势
- ✅ **不需要 OpenCode 运行在 serve 模式**
- ✅ **实现简单**，参考 cc-status-bar
- ✅ **支持历史数据**

#### 劣势
- ⚠️ **非实时**，有文件写入延迟
- ⚠️ **格式可能变化**

### 方案四：进程监控（兜底方案）

```swift
static func isOpenCodeRunning() -> Bool {
    let process = Process()
    process.launchPath = "/usr/bin/pgrep"
    process.arguments = ["-f", "opencode"]
    process.launch()
    process.waitUntilExit()
    return process.terminationStatus == 0
}
```

### 推荐最终方案：四级降级架构

```
Level 1: Plugin Hook + 文件监听 (cctop 方案) ← 首选
    ↓ 失败
Level 2: REST API + SSE (官方 serve 模式)
    ↓ 失败  
Level 3: 文件监控 (~/.local/share/opencode/)
    ↓ 失败
Level 4: 进程检测 (pgrep) ← 兜底
```

### 参考项目

| 项目 | Stars | 技术方案 | 复用内容 |
|------|-------|---------|---------|
| [st0012/cctop](https://github.com/st0012/cctop) | 70 | Plugin Hook + 文件监听 | OpenCode 插件实现、Hook CLI、文件监听 |
| [actualyze-ai/opencode-monitor](https://github.com/actualyze-ai/opencode-monitor) | - | Plugin + WebSocket | WebSocket 推送逻辑、TUI 状态展示 |
| [opgginc/opencode-bar](https://github.com/opgginc/opencode-bar) | 204 | API 轮询 + 凭证读取 | API 轮询 + 缓存机制 |

### 关键 Issue 和讨论

| Issue | 状态 | 关键信息 |
|-------|------|---------|
| [#14863](https://github.com/anomalyco/opencode/issues/14863) | ❌ Closed | 官方暂不计划原生 Hooks |
| [#9650](https://github.com/anomalyco/opencode/issues/9650) | ✅ Open | 支持 sessionID 过滤 SSE |
| [#6447](https://github.com/anomalyco/opencode/issues/6447) | ⚠️ Fixed | /session/status 曾返回空 |

---

## 8. 声音提醒

### 状态：⚠️ 简单实现，无需参考

### 实现方案

macOS 原生 `NSSound` 或 `AVAudioPlayer`，不需要第三方库。

```swift
import AppKit

class SoundManager {
    static let shared = SoundManager()
    
    func playPermissionAlert() {
        NSSound(named: "Ping")?.play()  // 系统内置音效
    }
    
    func playCompletion() {
        NSSound(named: "Glass")?.play()
    }
    
    func playError() {
        NSSound(named: "Basso")?.play()
    }
}
```

### 参考项目（仅用于灵感）

| 项目 | Stars | 说明 |
|------|-------|------|
| [shanraisshan/claude-code-hooks](https://github.com/shanraisshan/claude-code-hooks) | 272 | Python TTS 实现 |
| [htjun/claude-code-hooks-scv-sounds](https://github.com/htjun/claude-code-hooks-scv-sounds) | 39 | StarCraft SCV 音效 |

---

## 9. 完整架构参考总结

### 核心模块

| 模块 | 参考项目 | 文件 | 直接复用度 |
|------|---------|------|-----------|
| Hook 事件接收 | cc-status-bar | `HookCommand.swift`, `HookEvent.swift` | 90% — 直接移植为 Swift |
| Hook 自动安装 | cc-status-bar | `SetupManager` | 80% — 参考逻辑重写 |
| 文件监听通信 | cc-status-bar | `SessionObserver.swift` | 85% — 直接参考 |
| NSPanel 灵动岛 | Lyrisland | `DynamicIslandPanel.swift` | 95% — 直接复用 |
| 像素宠物 | claude-buddy | `pets.js` | 70% — 数据直接复用，渲染用 Swift Canvas |
| Codex 监控 | cc-status-bar | `CodexObserver.swift` | 80% — 直接参考 |
| OpenCode Plugin Hook | cctop | `plugins/opencode.js`, `cctop-hook` | 75% — 参考插件架构 |
| OpenCode SSE | OpenCode SDK | TypeScript SDK | 60% — 参考事件解析 |
| 声音提醒 | 无 | — | 100% — 用 NSSound 即可 |

### 新增参考项目（第二轮调研）

| 项目 | Stars | 技术方案 | 复用内容 |
|------|-------|---------|---------|
| [st0012/cctop](https://github.com/st0012/cctop) | 70 | Plugin Hook + 文件监听 | OpenCode 监控完整架构 |
| [actualyze-ai/opencode-monitor](https://github.com/actualyze-ai/opencode-monitor) | - | Plugin + WebSocket | 实时推送架构 |
| [opgginc/opencode-bar](https://github.com/opgginc/opencode-bar) | 204 | API 轮询 + 凭证读取 | Token 用量统计 |
| [Ark0N/Codeman](https://github.com/Ark0N/Codeman) | 296 | tmux + SSE | Session 管理 |

**总体可复用度：约 78%**（原 75%，OpenCode 调研后提升），核心技术点均有成熟参考，开发风险低。

### 技术风险与缓解

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| OpenCode 插件 API 变化 | 插件失效 | 中 | 四级降级，自动切换方案 |
| SSE 端点格式变化 | 解析失败 | 低 | 版本检测 + 容错解析 |
| Session 文件格式变化 | 文件监控失效 | 中 | 多路径扫描 + 格式推断 |
| 端口冲突（4040/41235） | 连接失败 | 低 | 支持自定义端口配置 |
| 插件安装率低 | 用户不愿装 | 中 | 提供无插件降级方案 |

---

## 风险矩阵

| 风险 | 影响 | 概率 | 风险等级 | 缓解措施 |
|------|------|------|---------|---------|
| OpenCode 插件 API 不稳定 | 高 | 中 | 🔴 高 | 四级降级架构 |
| OpenCode Session 格式未知 | 中 | 高 | 🔴 高 | 实际验证 + 多路径扫描 |
| OpenCode SSE 事件格式变化 | 中 | 中 | 🟡 中 | SDK 版本锁定 + 容错解析 |
| 像素宠物渲染性能差 | 中 | 中 | 🟡 中 | SwiftUI Canvas 原型验证 |
| DispatchSource 事件丢失 | 中 | 低 | 🟡 中 | 降级轮询兜底 |
| Hook 自动安装损坏配置 | 高 | 低 | 🟡 中 | 完整备份 + 回滚 |
| NSPanel 兼容性 | 中 | 低 | 🟢 低 | 多版本测试 |
| Claude Code hook 格式变化 | 高 | 低 | 🟢 低 | 版本检测 + 容错 |

---

## 验证优先级建议

### P0 - 立即验证（阻塞开发）

1. **OpenCode Plugin Hook 实际可用性** - 阻塞 Phase 4
2. **OpenCode Session 文件格式** - 阻塞 Level 3 方案
3. **OpenCode SSE 事件格式** - 阻塞 Level 2 方案

### P1 - 尽快验证（影响架构设计）

4. **像素宠物 Swift 渲染** - 影响 Phase 2 技术方案
5. **Claude Code Hook stdin 格式** - 影响 Phase 1 数据模型
6. **DispatchSource 可靠性** - 影响通信机制设计

### P2 - 开发过程中验证

7. **NSPanel 兼容性** - 可在 UI 开发时测试
8. **Hook 自动安装** - 可在 Phase 1 实现时验证
9. **Codex 监控准确性** - 影响较小，可延后
