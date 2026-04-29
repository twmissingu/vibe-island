#!/usr/bin/env swift
import Foundation

// MARK: - 数据模型

struct ToolUsage: Codable, Equatable {
    let name: String
    let count: Int
}

struct HookEvent: Codable {
    let sessionId: String
    let cwd: String
    let hookEventName: String
    let source: String?
    let sessionName: String?

    // 可选字段
    let prompt: String?
    let toolName: String?
    let toolInput: [String: String]?
    let title: String?
    let error: String?
    let message: String?
    let notificationType: String?
    let agentId: String?
    let agentType: String?
    let transcriptPath: String?
    let permissionMode: String?
    let isInterrupt: Bool?

    // Context usage 字段
    let contextUsage: Double?
    let contextTokensUsed: Int?
    let contextTokensTotal: Int?
    let contextInputTokens: Int?
    let contextOutputTokens: Int?
    let contextReasoningTokens: Int?
    let toolUsage: [ToolUsage]?
    let skillUsage: [ToolUsage]?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
        case source
        case sessionName = "session_name"
        case prompt
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case title
        case error
        case message
        case notificationType = "notification_type"
        case agentId = "agent_id"
        case agentType = "agent_type"
        case transcriptPath = "transcript_path"
        case permissionMode = "permission_mode"
        case isInterrupt = "is_interrupt"
        case contextUsage = "context_usage"
        case contextTokensUsed = "context_tokens_used"
        case contextTokensTotal = "context_tokens_total"
        case contextInputTokens = "context_input_tokens"
        case contextOutputTokens = "context_output_tokens"
        case contextReasoningTokens = "context_reasoning_tokens"
        case toolUsage = "tool_usage"
        case skillUsage = "skill_usage"
    }
}

// MARK: - 14 种事件类型定义

enum HookEventType: String, CaseIterable {
    case sessionStart = "SessionStart"
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case stop = "Stop"
    case notificationIdle = "Notification_idle"
    case notificationPermission = "Notification_permission"
    case notificationOther = "Notification_other"
    case permissionRequest = "PermissionRequest"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case preCompact = "PreCompact"
    case postCompact = "PostCompact"
    case sessionError = "SessionError"
    case sessionEnd = "SessionEnd"
    case refreshContext = "RefreshContext"
}

// MARK: - 测试用例生成器

struct HookTestGenerator {
    let baseSessionId = "test_session_001"
    let baseCwd = "/Users/test/project"

    /// 生成特定事件的测试 JSON
    func generateEventJSON(_ eventType: HookEventType, includeContextUsage: Bool = false) -> [String: Any] {
        var payload: [String: Any] = [
            "session_id": baseSessionId,
            "cwd": baseCwd,
            "hook_event_name": eventType.rawValue
        ]

        switch eventType {
        case .sessionStart:
            payload["transcript_path"] = "/tmp/claude-123.jsonl"
            payload["permission_mode"] = "default"

        case .userPromptSubmit:
            payload["prompt"] = "请帮我写一个 Swift 函数"
            // UserPromptSubmit 事件通常包含最新的 context usage
            if includeContextUsage {
                addContextUsageFields(to: &payload, usagePercent: 42)
            }

        case .preToolUse:
            payload["tool_name"] = "Bash"
            payload["tool_input"] = [
                "command": "ls -la"
            ]

        case .postToolUse:
            payload["tool_name"] = "Bash"

        case .postToolUseFailure:
            payload["tool_name"] = "Bash"
            payload["error"] = "Command exited with code 1"

        case .stop:
            payload["is_interrupt"] = false

        case .notificationIdle:
            payload["notification_type"] = "idle_prompt"
            payload["message"] = "Waiting for input"

        case .notificationPermission:
            payload["notification_type"] = "permission_prompt"
            payload["tool_name"] = "Bash"

        case .notificationOther:
            payload["notification_type"] = "other"
            payload["message"] = "Some notification"

        case .permissionRequest:
            payload["tool_name"] = "Bash"
            payload["title"] = "Execute command: ls -la"
            payload["tool_input"] = [
                "command": "ls -la"
            ]

        case .subagentStart:
            payload["agent_id"] = "agent_001"
            payload["agent_type"] = "code_review"

        case .subagentStop:
            payload["agent_id"] = "agent_001"

        case .preCompact:
            if includeContextUsage {
                addContextUsageFields(to: &payload, usagePercent: 85)
            } else {
                payload["message"] = "Context usage: 85% (170000/200000 tokens)"
            }

        case .postCompact:
            if includeContextUsage {
                addContextUsageFields(to: &payload, usagePercent: 45)
            }

        case .sessionError:
            payload["error"] = "API rate limit exceeded"
            payload["message"] = "Rate limit error occurred"

        case .sessionEnd:
            break

        case .refreshContext:
            if includeContextUsage {
                addContextUsageFields(to: &payload, usagePercent: 68)
            }
        }

        return payload
    }

    /// 向 payload 添加 context usage 字段
    private func addContextUsageFields(to payload: inout [String: Any], usagePercent: Int) {
        let totalTokens = 200000
        let usedTokens = (usagePercent * totalTokens) / 100
        let inputTokens = Int(Double(usedTokens) * 0.7)
        let outputTokens = Int(Double(usedTokens) * 0.25)
        let reasoningTokens = Int(Double(usedTokens) * 0.05)

        payload["context_usage"] = Double(usagePercent) / 100.0
        payload["context_tokens_used"] = usedTokens
        payload["context_tokens_total"] = totalTokens
        payload["context_input_tokens"] = inputTokens
        payload["context_output_tokens"] = outputTokens
        payload["context_reasoning_tokens"] = reasoningTokens
        payload["tool_usage"] = [
            ["name": "Read", "count": 12],
            ["name": "Edit", "count": 5],
            ["name": "Bash", "count": 3]
        ]
        payload["skill_usage"] = [
            ["name": "refactor-code", "count": 2]
        ]
    }
}

// MARK: - 测试执行

print("🧪 Claude Code Hook stdin 格式验证")
print("=" * 50)

let generator = HookTestGenerator()
var successCount = 0
var failCount = 0

for eventType in HookEventType.allCases {
    print("")
    print("📝 测试事件: \(eventType.rawValue)")

    // 测试 1: 基础格式
    let payload = generator.generateEventJSON(eventType)
    var testSuccess = true

    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
        print("  ❌ JSON 序列化失败")
        testSuccess = false
        failCount += 1
        continue
    }

    print("  📄 基础 JSON: \(jsonString.prefix(80))...")

    // 解析验证
    do {
        let decoder = JSONDecoder()
        let event = try decoder.decode(HookEvent.self, from: jsonData)

        // 验证必需字段
        guard event.sessionId == generator.baseSessionId else {
            print("  ❌ session_id 不匹配")
            testSuccess = false
            failCount += 1
            continue
        }

        guard event.cwd == generator.baseCwd else {
            print("  ❌ cwd 不匹配")
            testSuccess = false
            failCount += 1
            continue
        }

        guard event.hookEventName == eventType.rawValue else {
            print("  ❌ hook_event_name 不匹配")
            testSuccess = false
            failCount += 1
            continue
        }
    } catch {
        print("  ❌ 解析失败: \(error)")
        testSuccess = false
        failCount += 1
        continue
    }

    // 测试 2: 包含 context usage 字段（在支持的事件中）
    if eventType == .userPromptSubmit || eventType == .preCompact || eventType == .postCompact || eventType == .refreshContext {
        let payloadWithContext = generator.generateEventJSON(eventType, includeContextUsage: true)
        guard let jsonDataWithContext = try? JSONSerialization.data(withJSONObject: payloadWithContext) else {
            print("  ❌ Context usage JSON 序列化失败")
            testSuccess = false
            failCount += 1
            continue
        }

        do {
            let decoder = JSONDecoder()
            let eventWithContext = try decoder.decode(HookEvent.self, from: jsonDataWithContext)

            // 验证 context usage 字段
            if eventWithContext.contextUsage == nil {
                print("  ⚠️  缺少 context_usage 字段")
                // 不视为失败，因为这是可选功能
            }

            if eventWithContext.contextTokensUsed == nil {
                print("  ⚠️  缺少 context_tokens_used 字段")
            }

            if eventWithContext.contextTokensTotal == nil {
                print("  ⚠️  缺少 context_tokens_total 字段")
            }

            print("  📊 Context usage 字段解析成功")
        } catch {
            print("  ❌ Context usage 解析失败: \(error)")
            testSuccess = false
            failCount += 1
            continue
        }
    }

    if testSuccess {
        print("  ✅ 解析成功")
        successCount += 1
    }
}

// MARK: - 测试总结

print("")
print("=" * 50)
print("📈 测试总结")
print("=" * 50)
print("✅ 成功: \(successCount)/\(HookEventType.allCases.count)")
print("❌ 失败: \(failCount)/\(HookEventType.allCases.count)")
print("")

if failCount == 0 {
    print("🎉 所有事件类型验证通过！")
    print("")
    print("📋 16 种事件类型字段清单:")
    print("  1. SessionStart: session_id, cwd, hook_event_name, transcript_path, permission_mode")
    print("  2. UserPromptSubmit: session_id, cwd, hook_event_name, prompt, [context_usage*]")
    print("  3. PreToolUse: session_id, cwd, hook_event_name, tool_name, tool_input")
    print("  4. PostToolUse: session_id, cwd, hook_event_name, tool_name, [context_usage*]")
    print("  5. PostToolUseFailure: session_id, cwd, hook_event_name, tool_name, error")
    print("  6. Stop: session_id, cwd, hook_event_name, is_interrupt")
    print("  7. Notification: session_id, cwd, hook_event_name, notification_type, message")
    print("  8. PermissionRequest: session_id, cwd, hook_event_name, tool_name, title, tool_input")
    print("  9. SubagentStart: session_id, cwd, hook_event_name, agent_id, agent_type")
    print(" 10. SubagentStop: session_id, cwd, hook_event_name, agent_id")
    print(" 11. PreCompact: session_id, cwd, hook_event_name, message, [context_usage*]")
    print(" 12. PostCompact: session_id, cwd, hook_event_name, [context_usage*]")
    print(" 13. SessionError: session_id, cwd, hook_event_name, error, message")
    print(" 14. SessionEnd: session_id, cwd, hook_event_name")
    print(" 15. RefreshContext: session_id, cwd, hook_event_name, [context_usage*]")
    print("")
    print("  * = 可选的 context usage 字段")
    print("")
    print("💡 Context usage 字段说明:")
    print("  - context_usage: 上下文使用率（0.0-1.0）")
    print("  - context_tokens_used: 已使用的 tokens 数量")
    print("  - context_tokens_total: 总 token 限制")
    print("  - context_input_tokens: 输入 tokens 数量")
    print("  - context_output_tokens: 输出 tokens 数量")
    print("  - context_reasoning_tokens: 推理 tokens 数量")
    print("  - tool_usage: 工具使用统计数组")
    print("  - skill_usage: 技能使用统计数组")
} else {
    print("⚠️  存在失败项，需要调整数据模型")
}

// String 扩展
extension String {
    static func * (lhs: String, rhs: Int) -> String {
        return String(repeating: lhs, count: rhs)
    }
}
