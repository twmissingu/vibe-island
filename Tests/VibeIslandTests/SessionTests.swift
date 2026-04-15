import XCTest
@testable import VibeIsland

// MARK: - Session 模型测试

final class SessionTests: XCTestCase {

    // MARK: 初始化测试

    func testSessionDefaultInitialization() {
        let session = Session(
            sessionId: "test-123",
            cwd: "/tmp/project"
        )

        XCTAssertEqual(session.sessionId, "test-123")
        XCTAssertEqual(session.cwd, "/tmp/project")
        XCTAssertEqual(session.status, .idle)
        XCTAssertTrue(session.activeSubagents.isEmpty)
        XCTAssertNil(session.branch)
        XCTAssertNil(session.source)
        XCTAssertNil(session.sessionName)
        XCTAssertNil(session.lastTool)
        XCTAssertNil(session.lastPrompt)
        XCTAssertNil(session.notificationMessage)
        XCTAssertNil(session.contextUsage)
    }

    func testSessionFullInitialization() {
        let date = Date()
        let session = Session(
            sessionId: "test-456",
            cwd: "/tmp/project",
            status: .thinking,
            lastActivity: date,
            branch: "main",
            source: "cli",
            sessionName: "My Session",
            lastTool: "Read",
            lastToolDetail: "{\"path\": \"file.txt\"}",
            lastPrompt: "Hello",
            notificationMessage: nil,
            activeSubagents: [],
            pid: 12345,
            pidStartTime: 1000.0,
            contextUsage: 0.75,
            contextTokensUsed: 15000,
            contextTokensTotal: 20000
        )

        XCTAssertEqual(session.sessionId, "test-456")
        XCTAssertEqual(session.status, .thinking)
        XCTAssertEqual(session.branch, "main")
        XCTAssertEqual(session.source, "cli")
        XCTAssertEqual(session.sessionName, "My Session")
        XCTAssertEqual(session.lastTool, "Read")
        XCTAssertEqual(session.lastPrompt, "Hello")
        XCTAssertEqual(session.pid, 12345)
        XCTAssertEqual(session.contextUsage, 0.75)
        XCTAssertEqual(session.contextTokensUsed, 15000)
        XCTAssertEqual(session.contextTokensTotal, 20000)
    }

    // MARK: 事件应用测试

    func testApplyUserPromptSubmit() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        let event = createEvent(
            hookEventName: .userPromptSubmit,
            prompt: "Fix the bug"
        )

        session.applyEvent(event)

        XCTAssertEqual(session.lastPrompt, "Fix the bug")
        XCTAssertEqual(session.status, .thinking)
    }

    func testApplyPreToolUse() {
        // 初始状态为 thinking（模拟用户已提交提示）
        var session = Session(sessionId: "test", cwd: "/tmp", status: .thinking)
        let event = createEvent(
            hookEventName: .preToolUse,
            toolName: "Write",
            toolInput: ["path": "file.txt", "content": "hello"]
        )

        session.applyEvent(event)

        XCTAssertEqual(session.lastTool, "Write")
        XCTAssertNotNil(session.lastToolDetail)
        XCTAssertEqual(session.status, .coding)
    }

    func testApplyPostToolUse() {
        var session = Session(sessionId: "test", cwd: "/tmp", status: .coding)
        let event = createEvent(
            hookEventName: .postToolUse,
            toolName: "Write"
        )

        session.applyEvent(event)

        XCTAssertEqual(session.lastTool, "Write")
        XCTAssertEqual(session.status, .thinking)
    }

    func testApplyPostToolUseFailure() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        let event = createEvent(
            hookEventName: .postToolUseFailure,
            toolName: "Write",
            error: "Permission denied"
        )

        session.applyEvent(event)

        XCTAssertEqual(session.lastTool, "Write")
        XCTAssertEqual(session.notificationMessage, "Permission denied")
        XCTAssertEqual(session.status, .error)
    }

    func testApplyPermissionRequest() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        let event = createEvent(
            hookEventName: .permissionRequest,
            title: "Allow file access?"
        )

        session.applyEvent(event)

        XCTAssertEqual(session.notificationMessage, "Allow file access?")
        XCTAssertEqual(session.status, .waitingPermission)
    }

    func testApplySessionError() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        let event = createEvent(
            hookEventName: .sessionError,
            error: "Connection lost"
        )

        session.applyEvent(event)

        XCTAssertEqual(session.notificationMessage, "Connection lost")
        XCTAssertEqual(session.status, .error)
    }

    func testApplyNotification() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        let event = createEvent(
            hookEventName: .notification,
            message: "Idle prompt"
        )

        session.applyEvent(event)

        XCTAssertEqual(session.notificationMessage, "Idle prompt")
    }

    func testApplySubagentStart() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        let event = createEvent(
            hookEventName: .subagentStart,
            agentId: "agent-1",
            agentType: "coder"
        )

        session.applyEvent(event)

        XCTAssertEqual(session.activeSubagents.count, 1)
        XCTAssertEqual(session.activeSubagents[0].agentId, "agent-1")
        XCTAssertEqual(session.activeSubagents[0].agentType, "coder")
    }

    func testApplySubagentStop() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        let startEvent = createEvent(
            hookEventName: .subagentStart,
            agentId: "agent-1",
            agentType: "coder"
        )
        session.applyEvent(startEvent)

        let stopEvent = createEvent(
            hookEventName: .subagentStop,
            agentId: "agent-1"
        )
        session.applyEvent(stopEvent)

        XCTAssertTrue(session.activeSubagents.isEmpty)
    }

    func testApplyPreCompact() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        let event = createEvent(
            hookEventName: .preCompact,
            message: "Context growing large"
        )

        session.applyEvent(event)

        XCTAssertEqual(session.notificationMessage, "Context growing large")
        XCTAssertEqual(session.status, .compacting)
    }

    func testApplyPostCompact() {
        var session = Session(sessionId: "test", cwd: "/tmp", status: .compacting)
        let event = createEvent(
            hookEventName: .postCompact
        )

        session.applyEvent(event)

        XCTAssertEqual(session.notificationMessage, "上下文已压缩")
        XCTAssertEqual(session.status, .thinking)
    }

    func testApplySessionEnd() {
        var session = Session(sessionId: "test", cwd: "/tmp", status: .thinking)
        let event = createEvent(
            hookEventName: .sessionEnd
        )

        session.applyEvent(event)

        XCTAssertEqual(session.status, .completed)
    }

    // MARK: 状态更新测试

    func testLastActivityUpdates() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        let oldActivity = session.lastActivity

        // 等待一小段时间
        Thread.sleep(forTimeInterval: 0.01)

        let event = createEvent(
            hookEventName: .userPromptSubmit
        )
        session.applyEvent(event)

        XCTAssertGreaterThan(session.lastActivity, oldActivity)
    }

    // MARK: Equatable 测试

    func testSessionEquality() {
        let now = Date()
        let session1 = Session(sessionId: "test", cwd: "/tmp", lastActivity: now)
        let session2 = Session(sessionId: "test", cwd: "/tmp", lastActivity: now)
        let session3 = Session(sessionId: "other", cwd: "/tmp", lastActivity: now)

        XCTAssertEqual(session1, session2)
        XCTAssertNotEqual(session1, session3)
    }

    // MARK: 完整工作流测试

    func testCompleteWorkflow() {
        var session = Session(sessionId: "test", cwd: "/tmp")
        XCTAssertEqual(session.status, .idle)

        // 用户提交提示
        session.applyEvent(createEvent(hookEventName: .userPromptSubmit, prompt: "Write a function"))
        XCTAssertEqual(session.status, .thinking)
        XCTAssertEqual(session.lastPrompt, "Write a function")

        // 工具调用前
        session.applyEvent(createEvent(hookEventName: .preToolUse, toolName: "Write"))
        XCTAssertEqual(session.status, .coding)
        XCTAssertEqual(session.lastTool, "Write")

        // 工具调用后
        session.applyEvent(createEvent(hookEventName: .postToolUse, toolName: "Write"))
        XCTAssertEqual(session.status, .thinking)

        // 会话结束
        session.applyEvent(createEvent(hookEventName: .sessionEnd))
        XCTAssertEqual(session.status, .completed)
    }

    // MARK: Helper

    private func createEvent(
        hookEventName: SessionEventName,
        prompt: String? = nil,
        toolName: String? = nil,
        toolInput: [String: String]? = nil,
        title: String? = nil,
        error: String? = nil,
        message: String? = nil,
        agentId: String? = nil,
        agentType: String? = nil,
        notificationType: NotificationType? = nil
    ) -> SessionEvent {
        var json: [String: Any] = [
            "session_id": "test-session",
            "cwd": "/tmp/project",
            "hook_event_name": hookEventName.rawValue
        ]

        if let prompt = prompt { json["prompt"] = prompt }
        if let toolName = toolName { json["tool_name"] = toolName }
        if let toolInput = toolInput { json["tool_input"] = toolInput }
        if let title = title { json["title"] = title }
        if let error = error { json["error"] = error }
        if let message = message { json["message"] = message }
        if let agentId = agentId { json["agent_id"] = agentId }
        if let agentType = agentType { json["agent_type"] = agentType }
        if let notificationType = notificationType { json["notification_type"] = notificationType.rawValue }

        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(SessionEvent.self, from: data)
    }
}
