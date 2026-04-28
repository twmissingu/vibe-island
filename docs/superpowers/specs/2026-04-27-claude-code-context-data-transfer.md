# Claude Code + OpenCode 上下文数据传递实现计划

## 背景

Vibe Island 需要通过 Hook 机制获取 Claude Code 和 OpenCode 的会话上下文数据（context_usage、token 统计等），并在 Dynamic Island UI 中展示。

## 目标

1. Claude Code 和 OpenCode 使用统一的 Hook 机制传递上下文数据
2. 即使 Vibe Island App 未运行，也不影响 AI Coding 工具使用（Fail Open）
3. 在 Dynamic Island 上展示上下文使用率等关键信息

## 数据流架构

```
Claude Code Hook                      OpenCode Plugin
~/.claude/settings.json            ~/.config/opencode/plugins/
      │                                      │
      ↓ stdin JSON                           ↓ event payload
vibe-island CLI hook <event>  ←───────  vibe-island CLI hook <event>
      │                                      │
      └──────────────────┬──────────────────┘
                         ↓
              HookHandler.handleEvent()
                         ↓
              Session JSON 文件
              ~/.vibe-island/sessions/<pid>.json
                         ↓
              VibeIsland App (IslandView)
```

## 实现方案

### 1. 修改 hooks-config.json（Claude Code Hook）

修改 `Sources/VibeIsland/Resources/hooks-config.json`，将所有 13 个 hook 事件的命令替换为调用 vibe-island CLI：

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": "startup",
      "hooks": [{
        "type": "command",
        "command": "~/.vibe-island/bin/vibe-island hook SessionStart",
        "timeout": 5,
        "async": true
      }]
    }],
    "UserPromptSubmit": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.vibe-island/bin/vibe-island hook UserPromptSubmit",
        "timeout": 5,
        "async": true
      }]
    }],
    "PreToolUse": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": "~/.vibe-island/bin/vibe-island hook PreToolUse",
        "timeout": 5,
        "async": true
      }]
    }],
    "PostToolUse": [...],
    "PreCompact": [...],
    "PostCompact": [...],
    "Stop": [...],
    "SessionEnd": [...],
    "PermissionRequest": [...],
    "SubagentStart": [...],
    "SubagentStop": [...],
    "Notification": [...],
    "RefreshContext": [...]
  }
}
```

### 2. 增强 OpenCode Plugin

修改 `scripts/vibe-island-opencode-plugin.js`，在 `chat.complete` 事件处理中增加更详细的 token 统计：

```javascript
callHook(hookBin, "UserPromptSubmit", {
  ...basePayload(),
  prompt: contextMsg,
  context_usage: usagePercent / 100,
  context_tokens_used: totalTokens,
  context_tokens_total: modelContextLimit,
  // 新增字段
  context_input_tokens: inputTokens,
  context_output_tokens: outputTokens,
  context_reasoning_tokens: reasoningTokens,
});
```

### 3. 修改 HookAutoInstaller

修改 `Sources/VibeIsland/Services/HookAutoInstaller.swift`：
- 确保自动安装时使用新的 CLI 调用格式
- 验证 hook 配置正确合并到 `~/.claude/settings.json`

## 字段映射

| 字段 | Claude Code Hook | OpenCode Plugin | SessionEvent |
|------|-----------------|-----------------|--------------|
| session_id | ✅ | ✅ | sessionId |
| cwd | ✅ | ✅ | cwd |
| hook_event_name | ✅ | ✅ | hookEventName |
| tool_name | ✅ | ✅ | toolName |
| tool_input | ✅ | ✅ | toolInput |
| prompt | ✅ | ✅ | prompt |
| context_usage | 依赖 Claude Code | 已实现 | contextUsage |
| context_tokens_used | 依赖 Claude Code | 已实现 | contextTokensUsed |
| context_tokens_total | 依赖 Claude Code | 已实现 | contextTokensTotal |
| context_input_tokens | 依赖 Claude Code | 新增 | contextInputTokens |
| context_output_tokens | 依赖 Claude Code | 新增 | contextOutputTokens |
| context_reasoning_tokens | 依赖 Claude Code | 新增 | contextReasoningTokens |

## 实现步骤

1. **修改 hooks-config.json** - 替换所有 hook 命令为调用 vibe-island CLI
2. **增强 OpenCode Plugin** - 完善 UserPromptSubmit 的 token 统计
3. **修改 HookAutoInstaller** - 确保自动安装使用新配置格式
4. **添加自动化测试** - 验证 hook 数据正确解析和传递
5. **验证 UI 展示** - 确认 ContextUsageView 正确显示数据

## 风险与注意事项

1. **Claude Code Hook payload**：Claude Code 在不同事件中提供的字段可能不同，需实际测试
2. **CLI 路径**：确保 `~/.vibe-island/bin/vibe-island` 路径正确
3. **Fail Open**：hook 命令不应阻塞 AI Coding，即使 App 未运行
4. **字段兼容性**：SessionEvent 已支持 snake_case → camelCase 映射

## 验收标准

- [ ] Claude Code Hook 自动安装成功
- [ ] OpenCode Plugin 正确传递 token 统计
- [ ] Dynamic Island 展示 context_usage 数据
- [ ] App 未运行时 AI Coding 正常工作
- [ ] 自动化测试通过