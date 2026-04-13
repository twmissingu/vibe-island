# OpenCode 监控技术方案 - 调研结论报告

> 调研日期：2026-04-13
> 目标：确定真正可实现的 OpenCode 监控方案

---

## 核心结论

**OpenCode 不具备类似 Claude Code 的 stdin hook 机制**，但存在 **4 种可行的监控方案**，按推荐优先级排序：

| 方案 | 可行性 | 实时性 | 实现难度 | 推荐指数 |
|------|--------|--------|----------|---------|
| **方案一：SSE 事件订阅** | ✅ 完全可行 | 实时 | 中 | ⭐⭐⭐⭐⭐ |
| **方案二：Session 文件监听** | ✅ 完全可行 | 准实时 | 低 | ⭐⭐⭐⭐ |
| **方案三：插件 Hooks + 外部命令** | ⚠️ 部分可行 | 准实时 | 中 | ⭐⭐⭐ |
| **方案四：进程监控降级方案** | ✅ 完全可行 | 低 | 极低 | ⭐⭐ |

---

## 方案一：SSE 事件订阅（⭐ 最推荐）

### 技术原理

OpenCode 提供本地 HTTP 服务（`opencode serve`），暴露 SSE（Server-Sent Events）端点，可实时推送事件流。

### 可用端点

| 端点 | 方法 | 作用域 | 说明 |
|------|------|--------|------|
| `GET /event` | GET | 实例特定 | 仅推送当前工作目录/项目的事件 |
| `GET /global/event` | GET | 全局 | 推送所有实例的事件 |

### 请求参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `directory` | query | 指定工作目录路径 |
| `x-opencode-directory` | header | 同上（请求头方式） |

### 事件格式

```
Content-Type: text/event-stream

data: {"payload":{"type":"server.connected","properties":{}}}
data: {"payload":{"type":"server.heartbeat","properties":{}}}
data: {"payload":{"type":"session.created","properties":{"id":"xxx","cwd":"/path"}}}
data: {"payload":{"type":"message.completed","properties":{"sessionId":"xxx"}}}
```

### 关键事件类型

| 事件 | 说明 | 关键字段 |
|------|------|---------|
| `server.connected` | 连接确认 | - |
| `server.heartbeat` | 心跳（30s） | - |
| `session.created` | 会话创建 | `id`, `cwd` |
| `session.completed` | 会话结束 | `id`, `cwd` |
| `message.created` | 消息创建 | `sessionId`, `content` |
| `message.completed` | 消息完成 | `sessionId` |
| `tool.executing` | 工具执行中 | `sessionId`, `toolName` |
| `file.edited` | 文件编辑 | `filePath` |

### Swift 实现思路

```swift
class OpenCodeSSEObserver: ObservableObject {
    @Published var sessions: [OpenCodeSession] = []
    
    private var session: URLSessionSessionProtocol?
    private let baseURL = URL(string: "http://localhost:4040")!
    
    func startWatching() {
        var request = URLRequest(url: baseURL.appendingPathComponent("/global/event"))
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // 使用 URLSession 建立 SSE 长连接
        // 解析 data: 行的 JSON 事件
        // 更新 sessions 状态
    }
    
    private func parseSSEEvent(_ rawData: String) {
        // 解析 SSE 格式：提取 data: 后的 JSON
        // 根据 payload.type 分发处理
    }
}
```

### 优势
- ✅ **真正的实时监控**，无需轮询
- ✅ **事件类型丰富**，可捕获 session/消息/工具级别状态
- ✅ **官方支持**，有 TypeScript/Python SDK 参考实现
- ✅ **跨实例监控**，`/global/event` 可同时监控多个项目

### 劣势
- ⚠️ 需要 OpenCode 处于 `serve` 模式运行
- ⚠️ SSE 长连接可能断开，需要重连机制
- ⚠️ 默认端口 4040 可能被占用

### 参考项目
- [cctop](https://github.com/st0012/cctop) - macOS 菜单栏应用，使用类似方式监控 Claude Code 和 OpenCode
- OpenCode 官方 SDK: `@opencode-ai/sdk` (TypeScript), `opencode-sdk-python`

---

## 方案二：Session 文件监听（⭐ 次推荐）

### 技术原理

OpenCode 将 session 数据持久化到本地文件系统，通过监控文件变化可获取状态更新。

### 数据存储路径

| 路径 | 说明 |
|------|------|
| `~/.local/share/opencode/` | 主数据目录（macOS/Linux） |
| `~/.local/share/opencode/storage/` | Session 数据存储 |
| `~/.local/share/opencode/auth.json` | 认证信息 |
| `~/.local/share/opencode/log/` | 日志文件 |
| `~/.local/share/opencode/project/` | 按项目组织的会话 |

### 文件格式

OpenCode 使用 **JSON 格式**（非 Claude Code 的 JSONL），存储在 SQLite 数据库或 JSON 文件中。

### Swift 实现思路（参考 CodexObserver）

```swift
enum OpenCodeFileObserver {
    private static let storagePath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/opencode/storage/")
    
    private static var fileWatcher: DispatchSourceFileSystemObject?
    
    static func startWatching() {
        // 1. 监控 storage 目录的文件创建/修改
        // 2. 使用 DispatchSource 监听文件变化
        // 3. 解析 JSON 文件获取 session 状态
        // 4. 防抖 + 降级轮询（同 cc-status-bar）
    }
    
    static func getActiveSessions() -> [OpenCodeSession] {
        // 读取并解析 session 文件
        // 返回活跃会话列表
    }
}
```

### 优势
- ✅ **不需要 OpenCode 运行在 serve 模式**
- ✅ **实现简单**，参考 cc-status-bar 的 CodexObserver
- ✅ **离线可用**，不依赖网络连接
- ✅ **支持历史数据**，可回溯过去的会话

### 劣势
- ⚠️ **非实时**，有文件写入延迟
- ⚠️ **格式可能变化**，OpenCode 更新可能破坏解析
- ⚠️ 需要**定期轮询**作为降级方案

---

## 方案三：插件 Hooks + 外部命令

### 技术原理

OpenCode 的插件系统支持 `session_completed` 和 `file_edited` 配置钩子，可触发外部命令。

### 配置方式（`opencode.jsonc`）

```json
{
  "hooks": {
    "file_edited": {
      "*.swift": ["/path/to/vibe-island hook OpenCodeFileEdited"]
    },
    "session_completed": [
      { "command": "/path/to/vibe-island hook OpenCodeSessionEnd" }
    ]
  }
}
```

### 插件系统可用钩子

| 钩子 | 触发时机 | 可用性 |
|------|---------|--------|
| `file_edited` | 文件编辑时 | ✅ 配置级别 |
| `session_completed` | 会话结束时 | ✅ 配置级别 |
| `tool.execute.before` | 工具执行前 | ⚠️ 需编写插件 |
| `tool.execute.after` | 工具执行后 | ⚠️ 需编写插件 |
| `event` | 事件总线事件 | ⚠️ 需编写插件 |

### 优势
- ✅ **可扩展**，支持自定义逻辑
- ✅ **事件类型丰富**（需编写插件）

### 劣势
- ⚠️ **不支持实时 stdin 推送**（与 Claude Code 不同）
- ⚠️ `file_edited` 和 `session_completed` **覆盖范围有限**
- ⚠️ 高级钩子（`tool.execute`）**需要编写 TS 插件**
- ⚠️ **用户需手动配置**，无法自动安装

---

## 方案四：进程监控降级方案

### 技术原理

通过检测 `opencode` 进程是否存在来判断活动状态。

### Swift 实现

```swift
static func isOpenCodeRunning() -> Bool {
    let process = Process()
    process.launchPath = "/usr/bin/pgrep"
    process.arguments = ["-f", "opencode"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.launch()
    process.waitUntilExit()
    
    return process.terminationStatus == 0
}
```

### 优势
- ✅ **实现极简**
- ✅ **无需任何配置**

### 劣势
- ❌ **只能判断是否运行**，无法获取会话状态
- ❌ **无法区分多个会话**
- ❌ **误判率高**（后台进程也算）

---

## 推荐最终方案：组合方案

### 架构设计

```
┌─────────────────────────────────────────────────┐
│              LLM Quota Island App               │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────────┐  ┌──────────────┐            │
│  │ SSE Observer │  │ File Observer│            │
│  │  (主方案)    │  │  (降级方案)  │            │
│  └──────┬───────┘  └──────┬───────┘            │
│         │                 │                     │
│         └────────┬────────┘                     │
│                  ▼                              │
│         ┌──────────────┐                       │
│         │ StateManager │                       │
│         └──────┬───────┘                       │
│                ▼                                │
│         ┌──────────────┐                       │
│         │  NSPanel UI  │                       │
│         └──────────────┘                       │
└─────────────────────────────────────────────────┘
```

### 工作逻辑

1. **首选 SSE 监控**
   - 尝试连接 `http://localhost:4040/global/event`
   - 订阅所有事件，实时更新 UI
   - 断线自动重连（指数退避）

2. **SSE 不可用时降级到文件监听**
   - 检测 OpenCode 是否运行在 serve 模式
   - 如未运行，回退到 `~/.local/share/opencode/storage/` 文件监听
   - 使用 DispatchSource + 防抖动

3. **最坏情况：进程监控**
   - 仅显示 "OpenCode 运行中"
   - 不显示会话详情

### 数据流

```
OpenCode (serve mode)
    ↓ SSE
SSE Observer → 解析事件 → 更新 SessionModel
                                    ↓
OpenCode (file mode)          StateManager
    ↓ 文件变化                     ↓
File Observer → 解析JSON → 更新 SessionModel
                                    ↓
                              NSPanel Dynamic Island
                                    ↓
                              UI 刷新 + 宠物动画
```

---

## 与 Claude Code Hook 的对比

| 特性 | Claude Code | OpenCode |
|------|-------------|----------|
| **stdin hook** | ✅ 12 种事件 | ❌ 不支持 |
| **自动安装** | ✅ 修改 settings.json | ❌ 需手动配置 |
| **实时事件** | ✅ 通过 hook | ✅ 通过 SSE |
| **Session 文件** | ✅ JSONL 格式 | ✅ JSON 格式 |
| **进程检测** | ✅ pgrep | ✅ pgrep |
| **官方 SDK** | ❌ 无 | ✅ TS/Python |

---

## 开源项目参考

| 项目 | Stars | 技术栈 | 复用内容 |
|------|-------|--------|---------|
| [st0012/cctop](https://github.com/st0012/cctop) | 70 | Swift/SwiftUI | macOS 菜单栏应用，监控 Claude + OpenCode |
| [opgginc/opencode-bar](https://github.com/opgginc/opencode-bar) | 204 | Swift | OpenCode API 用量监控 |
| [jacobjmc/OpenCodeMonitor](https://github.com/jacobjmc/OpenCodeMonitor) | - | Vite/Web | 桌面版 OpenCode 监控 |
| [usedhonda/cc-status-bar](https://github.com/usedhonda/cc-status-bar) | 77 | Swift | CodexObserver 实现可参考 |

---

## 实施建议

### 第一阶段（MVP）
1. 实现 SSE 观察者（参考 OpenCode TypeScript SDK）
2. 实现基本的事件解析（session.created/completed）
3. 集成到 NSPanel Dynamic Island

### 第二阶段
1. 实现文件监听降级方案
2. 添加进程检测兜底逻辑
3. 支持多会话同时显示

### 第三阶段
1. 支持 OpenCode 插件 hooks（可选）
2. 优化 SSE 重连策略和心跳处理
3. 添加历史会话回溯功能

---

## 技术风险

| 风险 | 影响 | 缓解措施 |
|------|------|---------|
| OpenCode SSE API 变化 | SSE 连接失效 | 降级到文件监听 |
| Session 文件格式变化 | 解析失败 | 添加版本检测和容错 |
| 端口冲突（4040） | SSE 不可用 | 支持自定义端口配置 |
| 多用户场景 | 数据混乱 | 按 cwd 隔离会话 |

---

## 结论

**OpenCode 监控完全可实现**，推荐采用 **SSE + 文件监听 + 进程检测** 三级降级方案：

- ✅ **SSE 是最佳方案**：实时、官方支持、有 SDK 参考
- ✅ **文件监听是可靠降级**：不依赖 serve 模式、离线可用
- ✅ **进程检测是兜底**：极简实现，确保至少有基础状态

**整体技术风险：低**，有 3 个成熟的开源项目可参考。
