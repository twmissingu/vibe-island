# OpenCode 监控技术方案 - 完整调研报告

> 调研日期：2026-04-13（含第二轮深度调研）
> 目标：确定真正可实现的 OpenCode 监控方案

---

## 核心结论

**OpenCode 不具备类似 Claude Code 的 stdin hook 机制**，但存在 **5 种可行的监控方案**，按推荐优先级排序：

| 方案 | 可行性 | 实时性 | 实现难度 | 推荐指数 | 参考项目 |
|------|--------|--------|----------|---------|---------|
| **Plugin Hook + 文件监听** | ✅ 完全可行 | 实时 | 中 | ⭐⭐⭐⭐⭐ | [cctop](https://github.com/st0012/cctop) (70⭐) |
| **Plugin + WebSocket** | ✅ 完全可行 | 实时 | 高 | ⭐⭐⭐⭐ | [opencode-monitor](https://github.com/actualyze-ai/opencode-monitor) |
| **REST API + SSE** | ✅ 完全可行 | 实时 | 中 | ⭐⭐⭐⭐ | OpenCode 官方 SDK |
| **Session 文件监听** | ✅ 完全可行 | 准实时 | 低 | ⭐⭐⭐ | cc-status-bar CodexObserver |
| **进程监控** | ✅ 完全可行 | 低 | 极低 | ⭐⭐ | - |

---

## 调研发现：5 个关键开源项目

| 项目 | Stars | 技术方案 | 核心机制 |
|------|-------|---------|---------|
| [st0012/cctop](https://github.com/st0012/cctop) | 70 | **Plugin Hook + 文件监听** | 安装 JS 插件 → 调用 CLI → 写 JSON 文件 → FileWatcher |
| [opgginc/opencode-bar](https://github.com/opgginc/opencode-bar) | 204 | **API 轮询 + 凭证读取** | 读取 auth.json → 调用 AI 供应商 API → 统计用量 |
| [actualyze-ai/opencode-monitor](https://github.com/actualyze-ai/opencode-monitor) | - | **Plugin + WebSocket** | 安装插件 → WebSocket 推送 → TUI 展示 |
| [Ark0N/Codeman](https://github.com/Ark0N/Codeman) | 296 | **tmux 管理 + SSE** | 托管到 tmux → REST API + SSE 事件流 |
| [Shlomob/ocmonitor-share](https://github.com/Shlomob/ocmonitor-share) | - | **CLI 工具** | 分析 session 数据，生成报告 |

---

## 方案深度解析

### 方案 A：Plugin Hook + 文件监听（参考 cctop，⭐ 最推荐）

#### 架构设计

```
┌──────────────────────────────────────────────────┐
│                   OpenCode TUI                    │
│  ┌────────────────────────────────────────────┐  │
│  │  ~/.config/opencode/plugins/cctop.js       │  │
│  │  - 拦截 session.status 事件                │  │
│  │  - 拦截 tool.execute 事件                  │  │
│  │  - 过滤非交互式后台会话                     │  │
│  │  - 调用 cctop-hook CLI                     │  │
│  └────────────────┬───────────────────────────┘  │
│                   │ 执行外部命令                  │
└───────────────────▼──────────────────────────────┘
                    │
    ┌───────────────▼───────────────┐
    │      cctop-hook (Swift)       │
    │  - 接收事件参数               │
    │  - 序列化为 JSON              │
    │  - 写入 ~/.cctop/sessions/    │
    └───────────────┬───────────────┘
                    │ 文件写入
    ┌───────────────▼───────────────┐
    │   cctop Menubar App (Swift)   │
    │  - FileWatcher 监听目录        │
    │  - 解析 JSON 文件              │
    │  - 更新 UI 状态                │
    │  - 检查 PID 存活               │
    └───────────────────────────────┘
```

#### 关键实现细节

**1. OpenCode 插件（vibe-island.js）**

```javascript
// 位置：~/.config/opencode/plugins/vibe-island.js
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

**2. hook-input.schema.json（数据契约）**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["event", "sessionID", "cwd"],
  "properties": {
    "event": {
      "type": "string",
      "enum": ["session.status", "tool.execute", "message.completed"]
    },
    "sessionID": { "type": "string" },
    "cwd": { "type": "string" },
    "status": { "type": "string" },
    "toolName": { "type": "string" },
    "timestamp": { "type": "number" },
    "pid": { "type": "number" }
  }
}
```

**3. 文件写入格式（~/.vibe-island/opencode-sessions/{sessionID}.json）**

```json
{
  "sessionID": "abc123",
  "cwd": "/Users/user/project",
  "status": "working",
  "lastActive": 1744531200000,
  "pid": 12345,
  "projectName": "my-project",
  "currentTool": "write",
  "message": "正在修改文件..."
}
```

**4. Swift 文件监听实现**

```swift
class SessionFileWatcher {
    private let sessionsDir: URL
    private var fileWatchers: [DispatchSourceFileSystemObject] = []

    func startWatching() {
        // 监听目录变化
        let fd = open(sessionsDir.path, O_EVTONLY)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete]
        )
        source.setEventHandler { [weak self] in
            self?.handleDirectoryChange()
        }
        source.resume()
    }

    private func parseSessionFile(_ url: URL) -> Session? {
        let data = try Data(contentsOf: url)
        let session = try JSONDecoder().decode(Session.self, from: data)

        // 验证 PID 是否存活
        guard isProcessRunning(pid: session.pid) else { return nil }

        return session
    }
}
```

#### 优势
- ✅ **真正的实时事件**，插件拦截 OpenCode 内部事件
- ✅ **不依赖 SSE/HTTP 服务**，TUI 模式也可用
- ✅ **已有完整实现**，70⭐ 项目，代码开源
- ✅ **文件通信简单可靠**，无网络依赖
- ✅ **自动过滤后台会话**，插件层可精确判断

#### 劣势
- ⚠️ **需用户手动安装插件**（复制到 `~/.config/opencode/plugins/`）
- ⚠️ **无法自动安装**（与 Claude Code 的 settings.json hooks 不同）
- ⚠️ **插件 API 可能变化**，OpenCode 更新可能破坏

---

### 方案 B：Plugin + WebSocket（opencode-monitor，⭐ 实时性最强）

#### 架构设计

```
┌───────────────────────────────────────────────┐
│           OpenCode Instance #1                 │
│  ┌─────────────────────────────────────────┐  │
│  │  OpenCode Monitor Plugin (TypeScript)   │  │
│  │  - 拦截事件总线                         │  │
│  │  - 计算 Token 用量                      │  │
│  │  - WebSocket 推送到 TUI                 │  │
│  └───────────────┬─────────────────────────┘  │
└──────────────────┼─────────────────────────────┘
                   │ WebSocket (ws://host:41235)
┌──────────────────▼─────────────────────────────┐
│           OpenCode Instance #2                  │
│  ┌─────────────────────────────────────────┐  │
│  │  同样的 Plugin                          │  │
│  └───────────────┬─────────────────────────┘  │
└──────────────────┼─────────────────────────────┘
                   │
    ┌──────────────▼───────────────┐
    │    opencode-monitor TUI      │
    │  - WebSocket 服务端           │
    │  - 聚合多源数据               │
    │  - 实时展示 + 桌面通知        │
    └───────────────────────────────┘
```

#### 关键实现

**1. 插件配置（opencode.jsonc）**

```jsonc
{
  "plugin": {
    "opencode-monitor": {
      "enabled": true,
      "monitorHost": "localhost",
      "monitorPort": 41235,
      "monitorToken": "shared-secret"  // 可选
    }
  }
}
```

**2. WebSocket 消息格式**

```typescript
interface SessionUpdate {
  type: "session_update"
  sessionID: string
  cwd: string
  status: "idle" | "working" | "waiting" | "completed" | "error"
  tokens: {
    input: number
    output: number
    cache: number
    reasoning: number
  }
  cost: number
  contextWindowUsage: number  // 0-100
  timestamp: number
}
```

**3. TUI 状态指示器**

| 符号 | 状态 | 颜色 |
|------|------|------|
| `●` | 空闲 (idle) | 绿色 |
| `◐` | 忙碌/重试 | 黄色 |
| `◉` | 等待权限 | 橙色 |
| `○` | 完成 | 灰色 |
| `✕` | 错误/中止 | 红色 |

#### 优势
- ✅ **WebSocket 实时推送**，最低延迟
- ✅ **支持跨机器监控**，分布式架构
- ✅ **Token 用量精确统计**，插件内计算
- ✅ **桌面通知集成**，状态变化即推送

#### 劣势
- ⚠️ **需安装插件**，无法自动部署
- ⚠️ **WebSocket 端口管理**（默认 41235）
- ⚠️ **多实例连接维护**，复杂度较高

---

### 方案 C：REST API + SSE（官方支持）

#### 可用 REST API 端点

| 端点 | 方法 | 说明 |
|------|------|------|
| `/session/list` | GET | 列出所有会话 |
| `/session/{id}` | GET | 获取会话详情 |
| `/session/{id}/status` | GET | 获取会话状态 |
| `/session/{id}/todo` | GET | 获取会话 TODO 列表 |
| `/global/event` | GET (SSE) | 全局事件流 |
| `/event` | GET (SSE) | 实例特定事件流 |
| `/api/sessions` | GET | Web UI 会话列表 |
| `/api/events` | GET (SSE) | Web UI 事件流 |

#### SSE 事件格式

```
event: message
data: {"payload":{"type":"session.created","properties":{"id":"xxx","cwd":"/path","parentID":null}}}

event: message
data: {"payload":{"type":"session.status","properties":{"sessionID":"xxx","status":"working"}}}

event: message
data: {"payload":{"type":"message.completed","properties":{"sessionID":"xxx"}}}

event: message
data: {"payload":{"type":"tool.execute","properties":{"sessionID":"xxx","tool":"write","file":"..."}}}
```

#### Swift SSE 客户端实现

```swift
class OpenCodeSSEClient {
    private let baseURL: URL
    private var dataTask: URLSessionDataTask?
    private var buffer = ""

    func subscribe(to sessionID: String? = nil) {
        var request = URLRequest(url: baseURL.appendingPathComponent("/global/event"))
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")

        dataTask = URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let data = data, let chunk = String(data: data, encoding: .utf8) else { return }
            self?.buffer += chunk
            self?.parseSSEEvents()
        }
        dataTask?.resume()
    }

    private func parseSSEEvents() {
        let lines = buffer.components(separatedBy: "\n")
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonStr = String(line.dropFirst(6))
                if let event = try? JSONDecoder().decode(SSEEvent.self, from: jsonStr.data(using: .utf8)!) {
                    handleEvent(event)
                }
            }
        }
        buffer = ""  // 清空已处理的缓冲
    }
}
```

#### 优势
- ✅ **官方支持**，无需插件安装
- ✅ **无需修改 OpenCode 配置**
- ✅ **有 TypeScript/Python SDK**参考
- ✅ **支持 sessionID 过滤**（Issue #9650 已支持）

#### 劣势
- ⚠️ **需 `opencode serve` 模式**，TUI 模式不可用
- ⚠️ **SSE 长连接可能断开**，需重连机制
- ⚠️ **端口默认 4040**，可能冲突
- ⚠️ **部分 API 不稳定**（Issue #6447 报告 /session/status 返回空）

---

### 方案 D：文件监控降级方案（参考 cc-status-bar）

#### OpenCode 数据存储结构

```
~/.local/share/opencode/
├── auth.json                    # 认证信息
├── storage/                     # Session 数据
│   ├── {project-hash}/
│   │   ├── sessions.json        # 会话列表
│   │   └── {session-id}/
│   │       ├── messages.json    # 消息历史
│   │       └── metadata.json    # 会话元数据
├── log/                         # 日志
└── project/                     # 按项目组织
```

#### Swift 文件监控实现

```swift
enum OpenCodeFileObserver {
    private static let storagePath = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".local/share/opencode/storage/")

    private static var directorySource: DispatchSourceFileSystemObject?
    private static var sessionCache: [String: OpenCodeSession] = [:]

    static func startWatching() {
        // 1. 监控 storage 目录
        let fd = open(storagePath.path, O_EVTONLY)
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: DispatchQueue.global()
        )

        source.setEventHandler {
            self.handleStorageChange()
        }
        source.resume()
        directorySource = source

        // 2. 初始扫描
        scanSessions()
    }
}
```

#### 优势
- ✅ **不需要任何配置**
- ✅ **TUI/serve 模式均可用**
- ✅ **支持历史数据回溯**
- ✅ **实现简单**

#### 劣势
- ⚠️ **非实时**，有文件写入延迟
- ⚠️ **格式可能变化**
- ⚠️ **JSON 格式未官方文档化**

---

### 方案 E：进程监控兜底方案

#### 实现

```swift
static func detectOpenCodeSessions() -> [OpenCodeSession] {
    let task = Process()
    task.launchPath = "/bin/ps"
    task.arguments = ["aux"]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    var sessions: [OpenCodeSession] = []

    for line in output.components(separatedBy: "\n") {
        if line.contains("opencode") && !line.contains("grep") {
            // 提取 cwd（从进程参数）
            // 提取 PID
            sessions.append(OpenCodeSession(pid: pid, cwd: cwd))
        }
    }

    return sessions
}
```

#### 优势
- ✅ **极简实现**
- ✅ **无需任何配置**

#### 劣势
- ❌ **只能判断是否运行**
- ❌ **无法获取会话状态**
- ❌ **无法区分多个会话**

---

## 综合对比：5 种方案

| 维度 | Plugin Hook<br>(cctop) | Plugin + WS<br>(opencode-monitor) | REST + SSE | 文件监控 | 进程检测 |
|------|----------------------|----------------------------------|-----------|---------|---------|
| **实时性** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐ |
| **实现难度** | 中 | 高 | 中 | 低 | 极低 |
| **需安装插件** | ✅ | ✅ | ❌ | ❌ | ❌ |
| **自动安装** | ❌ | ❌ | ✅ | ✅ | ✅ |
| **TUI 模式** | ✅ | ✅ | ❌ | ✅ | ✅ |
| **Serve 模式** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Token 统计** | ❌ | ✅ | ❌ | ❌ | ❌ |
| **会话状态** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **跨机器** | ❌ | ✅ | ❌ | ❌ | ❌ |
| **参考项目** | cctop (70⭐) | opencode-monitor | OpenCode SDK | cc-status-bar | - |

---

## 推荐最终方案：四级降级架构

### 架构设计

```
┌─────────────────────────────────────────────────┐
│              LLM Quota Island App               │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────────┐  ┌──────────────┐            │
│  │ Plugin Hook  │  │ REST + SSE   │            │
│  │  (首选)      │  │  (备选)      │            │
│  └──────┬───────┘  └──────┬───────┘            │
│         │                 │                     │
│         └────────┬────────┘                     │
│                  ▼                              │
│         ┌──────────────┐                       │
│         │ StateManager │                       │
│         └──────┬───────┘                       │
│                │ 失败时降级                     │
│                ▼                                │
│         ┌──────────────┐                       │
│         │ File Observer│                       │
│         └──────┬───────┘                       │
│                │ 失败时降级                     │
│                ▼                                │
│         ┌──────────────┐                       │
│         │ Process Check│                       │
│         └──────┬───────┘                       │
│                ▼                                │
│         ┌──────────────┐                       │
│         │  NSPanel UI  │                       │
│         └──────────────┘                       │
└─────────────────────────────────────────────────┘
```

### 工作逻辑

#### 级别 1：Plugin Hook（cctop 方案）- 推荐首选

**条件**：用户安装了 OpenCode 插件

**实现步骤**：
1. 提供安装脚本，将 `vibe-island.js` 复制到 `~/.config/opencode/plugins/`
2. 插件拦截 `session.status`、`tool.execute` 等事件
3. 调用 `vibe-island-hook` CLI，写入 JSON 文件
4. App 通过 DispatchSource 监听文件变化，实时更新 UI

**数据流**：
```
OpenCode TUI
    ↓ 触发事件
Plugin (vibe-island.js)
    ↓ 执行外部命令
vibe-island-hook --event session.status --session-id xxx
    ↓ 写入文件
~/.vibe-island/opencode-sessions/{sessionID}.json
    ↓ DispatchSource 监听
App StateManager
    ↓ 更新
NSPanel UI + 宠物动画
```

#### 级别 2：REST API + SSE - 零配置备选

**条件**：用户运行 `opencode serve`

**实现步骤**：
1. 检测端口 4040 是否可达
2. 建立 SSE 长连接到 `/global/event`
3. 解析事件流，更新会话状态
4. 断线自动重连（指数退避）

#### 级别 3：文件监控 - 离线降级

**条件**：TUI 模式，无插件安装

**实现步骤**：
1. 监控 `~/.local/share/opencode/storage/` 目录
2. 定期轮询（30s）+ DispatchSource 即时触发
3. 解析 session JSON 文件
4. 更新 UI（可能有延迟）

#### 级别 4：进程检测 - 最终兜底

**条件**：以上方案均不可用

**实现步骤**：
1. `ps aux | grep opencode` 或 `pgrep -f opencode`
2. 仅显示 "OpenCode 运行中"
3. 不显示会话详情

---

## 关键技术决策

### 决策 1：插件 vs 无插件

| 考虑因素 | 插件方案 | 无插件方案 |
|---------|---------|-----------|
| 实时性 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |
| 用户体验 | 需手动安装 | 零配置 |
| 可维护性 | 依赖 OpenCode 插件 API | 更稳定 |
| 推荐场景 | 高级用户、开发者 | 普通用户 |

**结论**：提供两种模式，插件方案作为可选增强。

### 决策 2：通信方式选择

| 方式 | 适用场景 | 推荐度 |
|------|---------|--------|
| 文件 + DispatchSource | 插件 Hook | ⭐⭐⭐⭐⭐ |
| SSE 长连接 | Serve 模式 | ⭐⭐⭐⭐ |
| WebSocket | 跨机器监控 | ⭐⭐⭐ |
| 轮询 REST API | 降级方案 | ⭐⭐ |

**结论**：插件场景用文件通信，Serve 场景用 SSE。

### 决策 3：Session 状态枚举

参考 OpenCode 官方事件定义：

```swift
enum OpenCodeSessionStatus: String, Codable {
    case idle = "idle"              // 空闲，等待输入
    case working = "working"        // 正在处理任务
    case waiting = "waiting"        // 等待权限审批
    case completed = "completed"    // 会话结束
    case error = "error"            // 错误/中止
    case retrying = "retrying"      // 重试中
}
```

---

## 安装流程设计

### 自动检测流程

```
启动 App
    ↓
检测 OpenCode 是否安装
    ├── 否 → 隐藏 OpenCode 监控模块
    └── 是 ↓
检测插件是否安装
    ├── 否 → 提示用户安装插件（提供一键安装脚本）
    └── 是 ↓
检测 serve 模式是否运行
    ├── 是 → 优先使用 SSE 方案
    └── 否 → 使用 Plugin Hook 方案
         ↓
开始监控
```

### 一键安装脚本

```bash
#!/bin/bash
# 安装 OpenCode 监控插件
PLUGIN_DIR="$HOME/.config/opencode/plugins"
mkdir -p "$PLUGIN_DIR"
cp vibe-island-opencode-plugin.js "$PLUGIN_DIR/vibe-island.js"
echo "✅ OpenCode 监控插件已安装"
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

## 开源项目参考代码索引

| 项目 | 关键文件 | 复用内容 |
|------|---------|---------|
| [cctop](https://github.com/st0012/cctop) | `plugins/opencode.js` | OpenCode 插件实现 |
| cctop | `Sources/cctop-hook/` | Hook CLI Swift 实现 |
| cctop | `menubar/SessionWatcher.swift` | 文件监听核心 |
| [opencode-monitor](https://github.com/actualyze-ai/opencode-monitor) | `src/plugin/` | WebSocket 推送逻辑 |
| opencode-monitor | `src/tui/` | TUI 状态展示 |
| [cc-status-bar](https://github.com/usedhonda/cc-status-bar) | `CodexObserver.swift` | 文件监控参考 |
| [opencode-bar](https://github.com/opgginc/opencode-bar) | `Services/` | API 轮询 + 缓存 |

---

## 技术风险与缓解

| 风险 | 影响 | 概率 | 缓解措施 |
|------|------|------|---------|
| OpenCode 插件 API 变化 | 插件失效 | 中 | 四级降级，自动切换方案 |
| SSE 端点格式变化 | 解析失败 | 低 | 版本检测 + 容错解析 |
| Session 文件格式变化 | 文件监控失效 | 中 | 多路径扫描 + 格式推断 |
| 端口冲突（4040/41235） | 连接失败 | 低 | 支持自定义端口配置 |
| 插件安装率低 | 用户不愿装 | 中 | 提供无插件降级方案 |
| OpenCode 官方不支持 Hooks | 无法自动安装 | 高 | 接受现状，提供手动安装 |

---

## 实施路线图

### Phase 1：MVP（核心功能）

- [ ] 实现 SSE 客户端（Serve 模式监控）
- [ ] 实现基本事件解析（session.created/status/completed）
- [ ] 集成到 StateManager
- [ ] NSPanel 显示 OpenCode 会话状态

### Phase 2：Plugin Hook 增强

- [ ] 编写 OpenCode 插件（参考 cctop.js）
- [ ] 实现 vibe-island-hook CLI
- [ ] 文件监控 + DispatchSource
- [ ] 提供一键安装脚本

### Phase 3：降级方案

- [ ] 实现文件监控降级
- [ ] 实现进程检测兜底
- [ ] 自动检测 + 智能切换方案
- [ ] 多会话并发监控

### Phase 4：优化与增强

- [ ] Token 用量统计（参考 opencode-bar）
- [ ] 桌面通知集成
- [ ] 历史会话回溯
- [ ] 宠物动画联动

---

## 结论

**OpenCode 监控完全可实现**，推荐采用 **四级降级架构**：

1. ✅ **Plugin Hook + 文件监听**（参考 cctop）- 实时性最佳
2. ✅ **REST API + SSE**（官方支持）- 零配置
3. ✅ **文件监控降级**（参考 cc-status-bar）- 离线可用
4. ✅ **进程检测兜底** - 极简实现

### 关键发现：

- **OpenCode 官方不支持类似 Claude Code 的 stdin hook**（Issue #14863 已关闭）
- **社区已有成熟方案**：cctop（Plugin Hook）、opencode-monitor（WebSocket）、opencode-bar（API 轮询）
- **推荐四级降级架构**，确保各种场景下都有基本监控能力
- **整体技术风险：低**，有多个开源项目可参考

---

## 附录：关键 Issue 和讨论

| Issue | 状态 | 关键信息 |
|-------|------|---------|
| [#14863](https://github.com/anomalyco/opencode/issues/14863) | ❌ Closed | 官方暂不计划原生 Hooks |
| [#9650](https://github.com/anomalyco/opencode/issues/9650) | ✅ Open | 支持 sessionID 过滤 SSE |
| [#6447](https://github.com/anomalyco/opencode/issues/6447) | ⚠️ Fixed | /session/status 曾返回空 |
| [#13416](https://github.com/anomalyco/opencode/issues/13416) | ⚠️ 讨论中 | SSE 在 serve 模式的稳定性 |
| [#10886](https://github.com/anomalyco/opencode/issues/10886) | ✅ 解决 | 如何知道 session 关闭 |
