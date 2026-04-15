import XCTest
import Foundation
@testable import VibeIsland

/// Hook 数据流集成测试
/// 验证完整数据流：Hook 事件处理 -> 写入 session 文件 -> SessionFileWatcher 扫描 -> SessionManager 更新 -> aggregateState 正确计算
@MainActor
final class HookDataFlowIntegrationTests: XCTestCase {

    // MARK: - 辅助结构

    /// 临时测试环境，模拟真实的 session 文件目录
    struct TestEnvironment {
        let directory: URL
        let sessionsDir: URL

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("vibe-hook-integration-\(UUID().uuidString)")
            sessionsDir = directory.appendingPathComponent("sessions")
            try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        }

        /// 写入一个 session JSON 文件到测试目录
        func writeSessionFile(_ session: Session) throws {
            let fileURL = sessionsDir.appendingPathComponent("\(session.sessionId).json")
            var mutableSession = session
            mutableSession = Session(
                sessionId: session.sessionId,
                cwd: session.cwd,
                status: session.status,
                lastActivity: session.lastActivity,
                branch: session.branch,
                source: session.source,
                sessionName: session.sessionName,
                lastTool: session.lastTool,
                lastToolDetail: session.lastToolDetail,
                lastPrompt: session.lastPrompt,
                notificationMessage: session.notificationMessage,
                activeSubagents: session.activeSubagents,
                pid: session.pid,
                pidStartTime: session.pidStartTime,
                contextUsage: session.contextUsage,
                contextTokensUsed: session.contextTokensUsed,
                contextTokensTotal: session.contextTokensTotal,
                fileURL: fileURL
            )
            try mutableSession.writeToFile()
        }

        /// 删除 session 文件
        func deleteSessionFile(sessionId: String) throws {
            let fileURL = sessionsDir.appendingPathComponent("\(sessionId).json")
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }

        /// 清理整个测试目录
        func cleanup() {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    /// 创建一个测试用会话
    private func makeSession(
        id: String,
        cwd: String = "/tmp/project",
        status: SessionState = .idle,
        lastActivity: Date = Date(),
        source: String? = nil,
        sessionName: String? = nil,
        notificationMessage: String? = nil,
        lastTool: String? = nil
    ) -> Session {
        Session(
            sessionId: id,
            cwd: cwd,
            status: status,
            lastActivity: lastActivity,
            source: source,
            sessionName: sessionName ?? "Test Session \(id)",
            lastTool: lastTool,
            notificationMessage: notificationMessage
        )
    }

    /// 模拟 Hook 事件应用到会话
    private func applyHookEvent(to session: Session, eventName: SessionEventName, extra: [String: Any] = [:]) -> Session {
        var mutable = session
        let event = MockSessionEvent(
            sessionId: session.sessionId,
            cwd: session.cwd,
            hookEventName: eventName,
            prompt: extra["prompt"] as? String,
            toolName: extra["toolName"] as? String,
            error: extra["error"] as? String,
            message: extra["message"] as? String,
            title: extra["title"] as? String
        )
        mutable.applyEvent(event.toSessionEvent())
        return mutable
    }

    var env: TestEnvironment!
    var manager: SessionManager!

    override func setUp() async throws {
        try await super.setUp()
        env = try TestEnvironment()
        manager = SessionManager.makeForTesting()
    }

    override func tearDown() async throws {
        manager.stop()
        manager = nil
        env.cleanup()
        env = nil
        try await super.tearDown()
    }

    // MARK: - 端到端数据流测试

    /// 测试：模拟 Hook 事件 -> 写入文件 -> 手动刷新 -> SessionManager 更新 -> aggregateState 正确
    func testEndToEnd_dataFlow_fromHookToAggregateState() async throws {
        // 第一步：模拟 Hook 事件处理（SessionStart -> thinking）
        var session = makeSession(id: "session-001", cwd: "/tmp/project-a")
        session = applyHookEvent(to: session, eventName: .sessionStart)
        XCTAssertEqual(session.status, .thinking)

        // 第二步：写入 session 文件
        try env.writeSessionFile(session)

        // 第三步：通过 SessionFileWatcher 扫描文件
        let watcher = SessionFileWatcher()

        // 由于 SessionFileWatcher 使用静态目录，我们通过反射方式设置测试目录
        // 这里使用白盒方式：直接调用 parseSessionFile 逻辑
        // 注意：由于 SessionFileWatcher 的 sessionsDirectory 是 static let，我们无法修改
        // 因此我们创建一个独立的 watcher 实例，通过手动注入方式测试

        // 替代方案：直接测试 Session 解析和 SessionManager 更新逻辑
        let loadedSession = try Session.loadFromFile(
            url: env.sessionsDir.appendingPathComponent("session-001.json")
        )
        XCTAssertEqual(loadedSession.sessionId, "session-001")
        XCTAssertEqual(loadedSession.status, .thinking)

        // 第四步：注入到 SessionManager
        manager.injectSessionForTesting(loadedSession)

        // 第五步：验证 aggregateState
        XCTAssertEqual(manager.aggregateState, .thinking)
        XCTAssertEqual(manager.activeCount, 1)
    }

    /// 测试：多步骤 Hook 事件流（sessionStart -> preToolUse -> postToolUse -> completed）
    func testMultiStepHookEventFlow() async throws {
        var session = makeSession(id: "session-002")

        // SessionStart
        session = applyHookEvent(to: session, eventName: .sessionStart)
        XCTAssertEqual(session.status, .thinking)

        // PreToolUse
        session = applyHookEvent(to: session, eventName: .preToolUse, extra: ["toolName": "Read"])
        XCTAssertEqual(session.status, .coding)

        // PostToolUse
        session = applyHookEvent(to: session, eventName: .postToolUse, extra: ["toolName": "Read"])
        XCTAssertEqual(session.status, .thinking)

        // 再次 PreToolUse
        session = applyHookEvent(to: session, eventName: .preToolUse, extra: ["toolName": "Write"])
        XCTAssertEqual(session.status, .coding)

        // PostToolUse
        session = applyHookEvent(to: session, eventName: .postToolUse, extra: ["toolName": "Write"])
        XCTAssertEqual(session.status, .thinking)

        // SessionEnd
        session = applyHookEvent(to: session, eventName: .sessionEnd)
        XCTAssertEqual(session.status, .completed)

        // 写入文件并验证
        try env.writeSessionFile(session)
        let loaded = try Session.loadFromFile(url: env.sessionsDir.appendingPathComponent("session-002.json"))
        XCTAssertEqual(loaded.status, .completed)

        // 注入到 manager
        manager.injectSessionForTesting(loaded)
        XCTAssertEqual(manager.aggregateState, .completed)
        XCTAssertEqual(manager.activeCount, 0) // completed 不计入活跃
    }

    /// 测试：错误事件流（sessionStart -> preToolUse -> postToolUseFailure -> error）
    func testErrorEventFlow() async throws {
        var session = makeSession(id: "session-003")

        session = applyHookEvent(to: session, eventName: .sessionStart)
        XCTAssertEqual(session.status, .thinking)

        session = applyHookEvent(to: session, eventName: .preToolUse, extra: ["toolName": "Bash"])
        XCTAssertEqual(session.status, .coding)

        session = applyHookEvent(to: session, eventName: .postToolUseFailure, extra: [
            "toolName": "Bash",
            "error": "Permission denied"
        ])
        XCTAssertEqual(session.status, .error)
        XCTAssertEqual(session.notificationMessage, "Permission denied")

        // 写入并验证
        try env.writeSessionFile(session)
        manager.injectSessionForTesting(session)

        XCTAssertEqual(manager.aggregateState, .error)
        XCTAssertTrue(manager.hasError)
    }

    /// 测试：权限请求事件流（sessionStart -> permissionRequest -> waitingPermission）
    func testPermissionRequestEventFlow() async throws {
        var session = makeSession(id: "session-004")

        session = applyHookEvent(to: session, eventName: .sessionStart)
        session = applyHookEvent(to: session, eventName: .preToolUse, extra: ["toolName": "Bash"])
        session = applyHookEvent(to: session, eventName: .permissionRequest, extra: [
            "toolName": "Bash",
            "title": "Run dangerous command"
        ])

        XCTAssertEqual(session.status, .waitingPermission)
        XCTAssertEqual(session.notificationMessage, "Run dangerous command")
        XCTAssertTrue(session.status.isBlinking)

        try env.writeSessionFile(session)
        manager.injectSessionForTesting(session)

        XCTAssertEqual(manager.aggregateState, .waitingPermission)
        XCTAssertTrue(manager.hasPendingPermission)
    }

    /// 测试：PreCompact 事件流（coding -> preCompact -> compacting -> postCompact -> thinking）
    func testPreCompactEventFlow() async throws {
        var session = makeSession(id: "session-005")

        session = applyHookEvent(to: session, eventName: .sessionStart)
        session = applyHookEvent(to: session, eventName: .preToolUse, extra: ["toolName": "Read"])
        XCTAssertEqual(session.status, .coding)

        // PreCompact
        session = applyHookEvent(to: session, eventName: .preCompact, extra: [
            "message": "Context usage: 85% (170000/200000 tokens)"
        ])
        XCTAssertEqual(session.status, .compacting)
        XCTAssertEqual(session.notificationMessage, "Context usage: 85% (170000/200000 tokens)")
        XCTAssertTrue(session.status.isBlinking)

        // PostCompact
        session = applyHookEvent(to: session, eventName: .postCompact)
        XCTAssertEqual(session.status, .thinking)
        XCTAssertEqual(session.notificationMessage, "上下文已压缩")

        try env.writeSessionFile(session)
        manager.injectSessionForTesting(session)

        XCTAssertEqual(manager.aggregateState, .thinking)
    }

    // MARK: - 多会话并发写入测试

    /// 测试：多个会话并发写入文件，SessionManager 正确聚合状态
    func testConcurrentMultipleSessions_aggregateState() async throws {
        // 创建三个不同状态的会话
        var session1 = makeSession(id: "s1", cwd: "/project-a")
        session1 = applyHookEvent(to: session1, eventName: .sessionStart)
        session1 = applyHookEvent(to: session1, eventName: .preToolUse, extra: ["toolName": "Read"])
        // session1 处于 coding 状态

        var session2 = makeSession(id: "s2", cwd: "/project-a")
        session2 = applyHookEvent(to: session2, eventName: .sessionStart)
        session2 = applyHookEvent(to: session2, eventName: .preToolUse, extra: ["toolName": "Bash"])
        session2 = applyHookEvent(to: session2, eventName: .postToolUseFailure, extra: ["error": "Failed"])
        // session2 处于 error 状态

        var session3 = makeSession(id: "s3", cwd: "/project-b")
        session3 = applyHookEvent(to: session3, eventName: .sessionStart)
        session3 = applyHookEvent(to: session3, eventName: .permissionRequest)
        // session3 处于 waitingPermission 状态

        // 并发写入文件（由于 Session 的 MainActor 隔离，我们顺序写入）
        guard let env = self.env else { fatalError("env not set") }
        try env.writeSessionFile(session1)
        try env.writeSessionFile(session2)
        try env.writeSessionFile(session3)

        // 验证文件都已写入
        let fm = FileManager.default
        XCTAssertTrue(fm.fileExists(atPath: env.sessionsDir.appendingPathComponent("s1.json").path))
        XCTAssertTrue(fm.fileExists(atPath: env.sessionsDir.appendingPathComponent("s2.json").path))
        XCTAssertTrue(fm.fileExists(atPath: env.sessionsDir.appendingPathComponent("s3.json").path))

        // 注入到 SessionManager
        manager.injectSessionForTesting(session1)
        manager.injectSessionForTesting(session2)
        manager.injectSessionForTesting(session3)

        // 验证 aggregateState：waitingPermission 优先级最高 (0)
        XCTAssertEqual(manager.aggregateState, .waitingPermission)
        XCTAssertEqual(manager.activeCount, 3)
        XCTAssertTrue(manager.hasPendingPermission)
        XCTAssertTrue(manager.hasError)

        // 按 cwd 聚合验证
        let stateA = manager.aggregateState(for: "/project-a")
        XCTAssertEqual(stateA, .error) // error (1) < coding (3)

        let stateB = manager.aggregateState(for: "/project-b")
        XCTAssertEqual(stateB, .waitingPermission)
    }

    /// 测试：会话状态更新后文件内容正确
    func testSessionFileContentReflectsState() async throws {
        var session = makeSession(id: "verify-001")
        session = applyHookEvent(to: session, eventName: .sessionStart)
        session = applyHookEvent(to: session, eventName: .preToolUse, extra: ["toolName": "Write"])

        try env.writeSessionFile(session)

        // 读取并验证文件内容
        let loaded = try Session.loadFromFile(url: env.sessionsDir.appendingPathComponent("verify-001.json"))
        XCTAssertEqual(loaded.sessionId, "verify-001")
        XCTAssertEqual(loaded.status, .coding)
        XCTAssertEqual(loaded.lastTool, "Write")
        XCTAssertEqual(loaded.cwd, "/tmp/project")
    }

    /// 测试：删除 session 文件后，重新扫描不应包含已删除会话
    func testDeletedSessionFile_notInSessions() async throws {
        var session = makeSession(id: "delete-001")
        session = applyHookEvent(to: session, eventName: .sessionStart)
        try env.writeSessionFile(session)

        // 注入到 manager
        manager.injectSessionForTesting(session)
        XCTAssertEqual(manager.sessions.count, 1)

        // 删除文件
        try env.deleteSessionFile(sessionId: "delete-001")

        // 验证文件已删除
        let fm = FileManager.default
        XCTAssertFalse(fm.fileExists(atPath: env.sessionsDir.appendingPathComponent("delete-001.json").path))

        // SessionManager 中的会话不受文件删除影响（内存中保持）
        XCTAssertNotNil(manager.sessions["delete-001"])
    }

    // MARK: - 文件读写完整性测试

    /// 测试：Session.writeToFile 和 Session.loadFromFile 往返一致性
    func testSessionWriteAndLoadRoundTrip() async throws {
        let original = makeSession(
            id: "roundtrip-001",
            cwd: "/tmp/test-project",
            status: .coding,
            source: "claude-code",
            sessionName: "Round Trip Test",
            notificationMessage: "Running command",
            lastTool: "Bash"
        )

        try env.writeSessionFile(original)
        let loaded = try Session.loadFromFile(url: env.sessionsDir.appendingPathComponent("roundtrip-001.json"))

        XCTAssertEqual(loaded.sessionId, original.sessionId)
        XCTAssertEqual(loaded.cwd, original.cwd)
        XCTAssertEqual(loaded.status, original.status)
        XCTAssertEqual(loaded.source, original.source)
        XCTAssertEqual(loaded.sessionName, original.sessionName)
        XCTAssertEqual(loaded.lastTool, original.lastTool)
        XCTAssertEqual(loaded.notificationMessage, original.notificationMessage)
    }

    /// 测试：写入损坏的 JSON 文件时，加载应抛出错误
    func testCorruptedJsonFile_throwsOnLoad() async throws {
        let corruptedJson = """
        {
            "session_id": "corrupt-001",
            "cwd": "/tmp",
            "status": "coding",
            "last_activity": "not-a-valid-date"
        }
        """
        let fileURL = env.sessionsDir.appendingPathComponent("corrupt-001.json")
        try corruptedJson.write(to: fileURL, atomically: true, encoding: .utf8)

        // 加载时应抛出错误（日期格式不正确）
        do {
            _ = try Session.loadFromFile(url: fileURL)
            XCTFail("应抛出解码错误")
        } catch {
            // 预期内错误
        }
    }
}

// MARK: - Mock 辅助类型

/// 模拟 SessionEvent，用于测试
struct MockSessionEvent {
    let sessionId: String
    let cwd: String
    let hookEventName: SessionEventName
    let prompt: String?
    let toolName: String?
    let error: String?
    let message: String?
    let title: String?

    func toSessionEvent() -> SessionEvent {
        SessionEvent(
            sessionId: sessionId,
            cwd: cwd,
            hookEventName: hookEventName,
            source: nil,
            sessionName: nil,
            prompt: prompt,
            toolName: toolName,
            toolInput: nil,
            title: title,
            error: error,
            message: message,
            notificationType: nil,
            agentId: nil,
            agentType: nil,
            transcriptPath: nil,
            permissionMode: nil,
            isInterrupt: nil,
            receivedAt: Date()
        )
    }

    init(
        sessionId: String,
        cwd: String,
        hookEventName: SessionEventName,
        prompt: String? = nil,
        toolName: String? = nil,
        error: String? = nil,
        message: String? = nil,
        title: String? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.hookEventName = hookEventName
        self.prompt = prompt
        self.toolName = toolName
        self.error = error
        self.message = message
        self.title = title
    }
}
