# Claude Code Context Usage 数据传递实现计划

## 背景

最近的代码提交已经解决了 OpenCode 的 context usage 数据传递问题，现在需要为 Claude Code 实现相同的功能，让灵动岛的上下文卡片也能显示 Claude Code 会话的详细数据。

## 现状分析

### ✅ 已完成的部分

1. **数据模型**（`Sources/CLI/SharedModels.swift`）
   - `SessionEvent` 已支持所有 context usage 字段
   - `Session` 已支持所有 context usage 字段
   - 编解码支持 snake_case 格式

2. **HookHandler**（`Sources/CLI/HookHandler.swift`）
   - 已能解析 context usage 字段
   - 已能解析 tool_usage 和 skill_usage
   - 目前在 `PreCompact`、`UserPromptSubmit`、`RefreshContext` 事件中处理

3. **ContextMonitor**（`Sources/VibeIsland/Services/ContextMonitor.swift`）
   - 能从 Session 数据生成 ContextUsageSnapshot
   - 支持从文件读取 context 数据
   - 支持阈值警告

4. **UI 组件**
   - `ContextUsageView`：紧凑视图显示
   - `ContextUsageCard`：详细卡片视图
   - `IslandView`：已集成显示

### ❌ 缺失的部分

1. **Claude Code hook 数据**：Claude Code 的 hook 事件目前可能没有发送 context usage 字段
2. **事件覆盖不全**：HookHandler 只在少数事件中处理 context usage
3. **Tool/skill 统计**：Claude Code 没有统计工具和技能使用次数

## 实现方案

采用**渐进式混合方案**，分两个阶段实现：

### 阶段 1：扩展现有 Hook 处理（立即可用）

**目标**：最大化利用 Claude Code 现有 hook 能力

1. **扩展 HookHandler 处理更多事件**
   - 在所有事件中都检查并处理 context usage 字段（如果存在）
   - 不仅仅是 `PreCompact`、`UserPromptSubmit`、`RefreshContext`

2. **添加 Tool 和 Skill 使用统计**
   - 在 `PreToolUse` 事件中统计工具使用
   - 在相关事件中统计技能使用（如果有）
   - 持久化统计数据到 Session

3. **改进 PreCompact 消息解析**
   - 增强正则表达式，提取更多信息（如果可用）

### 阶段 2：探索 Claude Code 插件/扩展机制（长期方案）

**目标**：如果 Claude Code 支持插件系统，实现类似 OpenCode 的完整方案

1. **调研 Claude Code 插件能力**
2. **如果可用，创建 Claude Code 插件**
3. **实现 token 使用跟踪**
4. **实现 tool/skill 使用统计**

## 具体实施步骤

### 步骤 1：扩展 HookHandler 事件处理

修改 `Sources/CLI/HookHandler.swift`：

```swift
// 在 handleEvent 中，移除对特定事件的限制
// 所有事件都处理 context usage 字段（如果存在）

// 当前代码（第 88 行左右）：
if event.hookEventName == .preCompact || event.hookEventName == .userPromptSubmit || event.hookEventName == .refreshContext {
    // 处理 context usage
}

// 修改为：所有事件都尝试处理 context usage
if let usage = event.contextUsage {
    // 处理 context usage
} else if let message = event.message {
    // 尝试从 message 解析
}
// 始终更新 tool/skill usage（如果有）
```

### 步骤 2：实现 Tool 使用统计

在 `HookHandler` 中添加工具使用统计逻辑：

1. 从 Session 文件读取现有统计
2. 在 `PreToolUse` 事件中增加计数
3. 保存回 Session

### 步骤 3：添加 RefreshContext 事件触发机制

如果 Claude Code 支持，在 UI 中添加上下文刷新按钮，触发数据更新。

### 步骤 4：更新测试

更新 `hook_format_test.swift`，包含 context usage 字段的测试用例。

### 步骤 5：文档更新

更新相关文档，说明 Claude Code 的 context usage 功能。

## 关键文件修改清单

| 文件 | 修改内容 | 优先级 |
|------|----------|--------|
| `Sources/CLI/HookHandler.swift` | 扩展事件处理范围，添加 tool 统计 | 🔴 高 |
| `Tests/VibeIslandTests/hook_format_test.swift` | 添加 context usage 测试用例 | 🟡 中 |
| `Sources/VibeIsland/Services/SessionManager.swift` | 确保所有事件都触发 context update | 🟡 中 |
| `README.md` | 更新功能说明 | 🟢 低 |

## 验证计划

1. **单元测试**：运行现有测试，确保没有 regression
2. **Hook 格式测试**：运行 `hook_format_test.swift`
3. **手动测试**：
   - 启动 Vibe Island app
   - 使用 Claude Code 进行一些操作
   - 验证上下文卡片是否显示数据

## 风险评估

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Claude Code hook 确实没有 context 数据 | 只能显示基本信息 | 阶段 1 仍然能提供一定价值（tool 统计） |
| 现有功能被破坏 | 功能失效 | 充分测试，保持向后兼容 |

## 后续优化方向

1. 如果 Claude Code 提供了更多 hook 数据，进一步集成
2. 添加更多 UI 显示选项
3. 实现历史数据记录和趋势分析
