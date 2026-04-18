# VibeIsland 核心服务层

**作用**: 包含所有核心监控、会话管理和多工具聚合服务

## 结构

主要服务列表：
- `SessionManager` - 管理 Claude Code 会话状态聚合
- `MultiToolAggregator` - 聚合 Claude/OpenCode 所有工具会话
- `OpenCodeMonitor` - OpenCode 四级降级监控（最复杂，989 行）
- `HookAutoInstaller` - 自动安装 Hook 脚本（最大文件，1030 行）
- `SessionFileWatcher` - 会话文件变更监听
- `StateManager` - 全局状态和设置管理
- `SoundManager` - 声音通知播放
- `ContextMonitor` - Claude Code 上下文使用率监控

## 在哪里找

| 任务 | 位置 |
|------|------|
| 修改 OpenCode 监控策略 | `OpenCodeMonitor.swift` |
| 修改会话聚合逻辑 | `MultiToolAggregator.swift` |
| 修改 Hook 安装逻辑 | `HookAutoInstaller.swift` |
| 修改文件监听逻辑 | `SessionFileWatcher.swift` |

## 约定

- 所有单例服务必须标记 `@MainActor`
- 文件变更监听使用 `DispatchSource`，不要轮询
- 每 3 秒自动聚合一次所有工具会话状态
- 所有服务启动后必须能正确停止，释放资源

## 反模式

- ❌ 不要移除状态优先级排序，优先级是核心特性
- ❌ 不要修改聚合间隔不经过讨论
- ❌ 不要在非 MainActor 线程修改会话状态
