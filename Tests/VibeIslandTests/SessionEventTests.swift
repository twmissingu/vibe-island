import XCTest
@testable import VibeIsland

// MARK: - SessionEvent 模型测试

final class SessionEventTests: XCTestCase {

    // MARK: 解码测试

    func testDecodeSessionStartEvent() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "SessionStart"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.sessionId, "abc-123")
        XCTAssertEqual(event.cwd, "/Users/test/project")
        XCTAssertEqual(event.hookEventName, .sessionStart)
        XCTAssertNil(event.prompt)
        XCTAssertNil(event.toolName)
    }

    func testDecodeUserPromptSubmitEvent() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "UserPromptSubmit",
            "prompt": "Write a Swift function to calculate fibonacci"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.hookEventName, .userPromptSubmit)
        XCTAssertEqual(event.prompt, "Write a Swift function to calculate fibonacci")
    }

    func testDecodePreToolUseEvent() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "PreToolUse",
            "tool_name": "Write",
            "tool_input": [
                "path": "/Users/test/project/file.swift",
                "content": "let x = 1"
            ]
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.hookEventName, .preToolUse)
        XCTAssertEqual(event.toolName, "Write")
        XCTAssertNotNil(event.toolInput)
        XCTAssertEqual(event.toolInput?["path"], "/Users/test/project/file.swift")
        XCTAssertEqual(event.toolInput?["content"], "let x = 1")
    }

    func testDecodePostToolUseFailureEvent() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "PostToolUseFailure",
            "tool_name": "Bash",
            "error": "Permission denied: /etc/hosts"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.hookEventName, .postToolUseFailure)
        XCTAssertEqual(event.toolName, "Bash")
        XCTAssertEqual(event.error, "Permission denied: /etc/hosts")
    }

    func testDecodePermissionRequestEvent() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "PermissionRequest",
            "tool_name": "Bash",
            "title": "Run command: rm -rf /tmp/test"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.hookEventName, .permissionRequest)
        XCTAssertEqual(event.title, "Run command: rm -rf /tmp/test")
    }

    func testDecodeNotificationEvent() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "Notification",
            "notification_type": "idle_prompt",
            "message": "Ready for input"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.hookEventName, .notification)
        XCTAssertEqual(event.notificationType, .idlePrompt)
        XCTAssertEqual(event.message, "Ready for input")
    }

    func testDecodeSubagentStartEvent() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "SubagentStart",
            "agent_id": "sub-001",
            "agent_type": "code-reviewer"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.hookEventName, .subagentStart)
        XCTAssertEqual(event.agentId, "sub-001")
        XCTAssertEqual(event.agentType, "code-reviewer")
    }

    func testDecodePreCompactEvent() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "PreCompact",
            "message": "Context window nearly full"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.hookEventName, .preCompact)
        XCTAssertEqual(event.message, "Context window nearly full")
    }

    func testDecodeSessionErrorEvent() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "SessionError",
            "error": "API rate limit exceeded",
            "message": "Please try again later"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.hookEventName, .sessionError)
        XCTAssertEqual(event.error, "API rate limit exceeded")
        XCTAssertEqual(event.message, "Please try again later")
    }

    func testDecodeEventWithOptionalFields() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/Users/test/project",
            "hook_event_name": "UserPromptSubmit",
            "source": "claude-code",
            "session_name": "My Coding Session",
            "prompt": "Hello",
            "permission_mode": "acceptEdits",
            "is_interrupt": true
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.source, "claude-code")
        XCTAssertEqual(event.sessionName, "My Coding Session")
        XCTAssertEqual(event.permissionMode, "acceptEdits")
        XCTAssertEqual(event.isInterrupt, true)
    }

    func testDecodeEventWithMinimalFields() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/tmp",
            "hook_event_name": "Stop"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let event = try! decoder.decode(SessionEvent.self, from: data)

        XCTAssertEqual(event.sessionId, "abc-123")
        XCTAssertEqual(event.cwd, "/tmp")
        XCTAssertEqual(event.hookEventName, .stop)
        XCTAssertNil(event.source)
        XCTAssertNil(event.prompt)
        XCTAssertNil(event.toolName)
        XCTAssertNil(event.error)
    }

    // MARK: SessionEventName 测试

    func testSessionEventNameAllCases() {
        let allCases = SessionEventName.allCases
        XCTAssertEqual(allCases.count, 14)

        let expectedCases: [SessionEventName] = [
            .sessionStart, .sessionEnd, .stop, .sessionError,
            .userPromptSubmit, .permissionRequest,
            .preToolUse, .postToolUse, .postToolUseFailure,
            .preCompact, .postCompact,
            .subagentStart, .subagentStop,
            .notification
        ]

        for testCase in expectedCases {
            XCTAssertTrue(allCases.contains(testCase), "Missing case: \(testCase.rawValue)")
        }
    }

    func testSessionEventNameDisplayNames() {
        XCTAssertEqual(SessionEventName.sessionStart.displayName, "会话开始")
        XCTAssertEqual(SessionEventName.sessionEnd.displayName, "会话结束")
        XCTAssertEqual(SessionEventName.stop.displayName, "停止")
        XCTAssertEqual(SessionEventName.sessionError.displayName, "会话错误")
        XCTAssertEqual(SessionEventName.userPromptSubmit.displayName, "用户提交提示")
        XCTAssertEqual(SessionEventName.permissionRequest.displayName, "权限请求")
        XCTAssertEqual(SessionEventName.preToolUse.displayName, "工具调用前")
        XCTAssertEqual(SessionEventName.postToolUse.displayName, "工具调用后")
        XCTAssertEqual(SessionEventName.postToolUseFailure.displayName, "工具调用失败")
        XCTAssertEqual(SessionEventName.preCompact.displayName, "压缩前")
        XCTAssertEqual(SessionEventName.postCompact.displayName, "压缩后")
        XCTAssertEqual(SessionEventName.subagentStart.displayName, "子代理启动")
        XCTAssertEqual(SessionEventName.subagentStop.displayName, "子代理停止")
        XCTAssertEqual(SessionEventName.notification.displayName, "通知")
    }

    func testSessionEventNameRawValues() {
        XCTAssertEqual(SessionEventName.sessionStart.rawValue, "SessionStart")
        XCTAssertEqual(SessionEventName.sessionEnd.rawValue, "SessionEnd")
        XCTAssertEqual(SessionEventName.stop.rawValue, "Stop")
        XCTAssertEqual(SessionEventName.sessionError.rawValue, "SessionError")
        XCTAssertEqual(SessionEventName.userPromptSubmit.rawValue, "UserPromptSubmit")
        XCTAssertEqual(SessionEventName.permissionRequest.rawValue, "PermissionRequest")
        XCTAssertEqual(SessionEventName.preToolUse.rawValue, "PreToolUse")
        XCTAssertEqual(SessionEventName.postToolUse.rawValue, "PostToolUse")
        XCTAssertEqual(SessionEventName.postToolUseFailure.rawValue, "PostToolUseFailure")
        XCTAssertEqual(SessionEventName.preCompact.rawValue, "PreCompact")
        XCTAssertEqual(SessionEventName.postCompact.rawValue, "PostCompact")
        XCTAssertEqual(SessionEventName.subagentStart.rawValue, "SubagentStart")
        XCTAssertEqual(SessionEventName.subagentStop.rawValue, "SubagentStop")
        XCTAssertEqual(SessionEventName.notification.rawValue, "Notification")
    }

    // MARK: NotificationType 测试

    func testNotificationTypeCases() {
        XCTAssertEqual(NotificationType.idlePrompt.rawValue, "idle_prompt")
        XCTAssertEqual(NotificationType.permissionPrompt.rawValue, "permission_prompt")
        XCTAssertEqual(NotificationType.other.rawValue, "other")
    }

    // MARK: 时间戳测试

    func testEventReceivedAtIsSet() {
        let json: [String: Any] = [
            "session_id": "abc-123",
            "cwd": "/tmp",
            "hook_event_name": "SessionStart"
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let beforeDecode = Date()
        let event = try! decoder.decode(SessionEvent.self, from: data)
        let afterDecode = Date()

        // receivedAt 应该在解码时设置
        XCTAssertGreaterThanOrEqual(event.receivedAt, beforeDecode)
        XCTAssertLessThanOrEqual(event.receivedAt, afterDecode)
    }
}
