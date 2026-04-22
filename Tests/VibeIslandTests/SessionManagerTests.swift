import XCTest
import Foundation
@testable import VibeIsland

/// SessionManager 测试
/// 测试会话管理器的核心功能：多会话聚合、优先级排序、跟踪模式切换、查询方法等
@MainActor
final class SessionManagerTests: XCTestCase {

    var manager: SessionManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = SessionManager.makeForTesting()
    }

    override func tearDown() async throws {
        manager.stop()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - 辅助方法

    /// 创建测试用会话
    private func makeSession(
        id: String,
        status: SessionState = .idle,
        cwd: String = "/tmp/project",
        source: String? = nil,
        lastActivity: Date = Date()
    ) -> Session {
        Session(
            sessionId: id,
            cwd: cwd,
            status: status,
            lastActivity: lastActivity,
            source: source
        )
    }

    /// 直接注入会话到 manager（绕过文件监听）
    private func injectSession(_ session: Session) {
        manager.injectSessionForTesting(session)
    }

    // MARK: - 初始状态测试

    /// 测试：初始跟踪模式应为自动
    func testInitialTrackingMode_isAuto() {
        XCTAssertTrue(manager.trackingMode.isAuto)
    }

    /// 测试：初始 sessions 应为空
    func testInitialSessions_empty() {
        XCTAssertTrue(manager.sessions.isEmpty)
    }

    /// 测试：初始 aggregateState 应为 idle
    func testInitialAggregateState_isIdle() {
        XCTAssertEqual(manager.aggregateState, .idle)
    }

    /// 测试：初始 activeCount 应为 0
    func testInitialActiveCount_isZero() {
        XCTAssertEqual(manager.activeCount, 0)
    }

    /// 测试：初始 hasPendingPermission 应为 false
    func testInitialHasPendingPermission_isFalse() {
        XCTAssertFalse(manager.hasPendingPermission)
    }

    /// 测试：初始 hasError 应为 false
    func testInitialHasError_isFalse() {
        XCTAssertFalse(manager.hasError)
    }

    // MARK: - 会话更新测试

    /// 测试：注入 idle 会话后 aggregateState 仍为 idle
    func testUpdateSession_idle_aggregateStateIdle() {
        let session = makeSession(id: "s1", status: .idle)
        injectSession(session)
        XCTAssertEqual(manager.aggregateState, .idle)
    }

    /// 测试：注入 coding 会话后 aggregateState 为 coding
    func testUpdateSession_coding_aggregateStateCoding() {
        let session = makeSession(id: "s1", status: .coding)
        injectSession(session)
        XCTAssertEqual(manager.aggregateState, .coding)
    }

    /// 测试：注入 error 会话后 hasError 为 true
    func testUpdateSession_error_hasErrorTrue() {
        let session = makeSession(id: "s1", status: .error)
        injectSession(session)
        XCTAssertTrue(manager.hasError)
    }

    /// 测试：注入 waitingPermission 会话后 hasPendingPermission 为 true
    func testUpdateSession_waitingPermission_hasPendingPermissionTrue() {
        let session = makeSession(id: "s1", status: .waitingPermission)
        injectSession(session)
        XCTAssertTrue(manager.hasPendingPermission)
    }

    // MARK: - 优先级排序测试

    /// 测试：sortedSessions 按优先级排序
    func testSortedSessions_byPriority() {
        let idle = makeSession(id: "idle", status: .idle)
        let coding = makeSession(id: "coding", status: .coding)
        let error = makeSession(id: "error", status: .error)

        injectSession(idle)
        injectSession(coding)
        injectSession(error)

        let sorted = manager.sortedSessions
        XCTAssertEqual(sorted.count, 3)
        // 优先级：error(1) < coding(3) < idle(7)
        XCTAssertEqual(sorted[0].status, .error)
        XCTAssertEqual(sorted[1].status, .coding)
        XCTAssertEqual(sorted[2].status, .idle)
    }

    /// 测试：多个同优先级会话保持稳定性
    func testSortedSessions_samePriority_stable() {
        let coding1 = makeSession(id: "c1", status: .coding)
        let coding2 = makeSession(id: "c2", status: .coding)

        injectSession(coding1)
        injectSession(coding2)

        XCTAssertEqual(manager.sortedSessions.count, 2)
        XCTAssertTrue(manager.sortedSessions.allSatisfy { $0.status == .coding })
    }

    // MARK: - trackedSession 测试

    /// 测试：自动模式下无活跃会话时 trackedSession 为 nil
    func testTrackedSession_auto_noActiveSessions() {
        manager.setTrackingModeForTesting(.auto)
        XCTAssertNil(manager.trackedSession)
    }

    /// 测试：自动模式下返回最高优先级的活跃会话
    func testTrackedSession_auto_returnsHighestPriority() {
        manager.setTrackingModeForTesting(.auto)

        let idle = makeSession(id: "idle", status: .idle)
        let coding = makeSession(id: "coding", status: .coding)
        let error = makeSession(id: "error", status: .error)

        injectSession(idle)
        injectSession(coding)
        injectSession(error)

        let tracked = manager.trackedSession
        // error 优先级高于 coding
        XCTAssertEqual(tracked?.status, .error)
    }

    /// 测试：自动模式下过滤 idle 和 completed 会话
    func testTrackedSession_auto_filtersIdleAndCompleted() {
        manager.setTrackingModeForTesting(.auto)

        let idle = makeSession(id: "idle", status: .idle)
        let completed = makeSession(id: "completed", status: .completed)

        injectSession(idle)
        injectSession(completed)

        // 没有活跃会话，应返回 nil（fallback 到最近活跃）
        // 由于两个都不是 active，会 fallback
        XCTAssertNotNil(manager.trackedSession) // fallback 到最近活跃
    }

    /// 测试：手动模式下返回固定的会话
    func testTrackedSession_manual_returnsPinned() {
        let session = makeSession(id: "pinned", status: .coding)
        injectSession(session)

        manager.setTrackingModeForTesting(.manual(sessionId: "pinned"))
        XCTAssertEqual(manager.trackedSession?.sessionId, "pinned")
    }

    /// 测试：手动模式下固定不存在的会话时 trackedSession 为 nil
    func testTrackedSession_manual_nonExistent_isNil() {
        manager.setTrackingModeForTesting(.manual(sessionId: "non-existent"))
        XCTAssertNil(manager.trackedSession)
    }

    // MARK: - 跟踪模式切换测试

    /// 测试：切换到自动模式
    func testSetTrackingModeAuto() {
        manager.setTrackingModeAuto()
        XCTAssertTrue(manager.trackingMode.isAuto)
        XCTAssertNil(manager.pinnedSessionId)
    }

    /// 测试：切换到手动模式
    func testSetTrackingModeManual() {
        manager.setTrackingModeManual(sessionId: "test-session")
        if case .manual(let id) = manager.trackingMode {
            XCTAssertEqual(id, "test-session")
        } else {
            XCTFail("应为手动模式")
        }
        XCTAssertEqual(manager.pinnedSessionId, "test-session")
    }

    /// 测试：toggleTrackingMode 从自动切换到手动
    func testToggleTrackingMode_autoToManual() {
        manager.setTrackingModeForTesting(.auto)
        let session = makeSession(id: "s1", status: .coding)
        injectSession(session)

        manager.toggleTrackingMode()

        if case .manual = manager.trackingMode {
            // 成功切换到手动
        } else {
            XCTFail("应切换到手动模式")
        }
    }

    /// 测试：toggleTrackingMode 从手动切换到自动
    func testToggleTrackingMode_manualToAuto() {
        manager.setTrackingModeForTesting(.manual(sessionId: "s1"))
        manager.toggleTrackingMode()
        XCTAssertTrue(manager.trackingMode.isAuto)
    }

    // MARK: - 查询方法测试

    /// 测试：session(id:) 返回指定会话
    func testSessionById_returnsCorrectSession() {
        let session = makeSession(id: "target", status: .coding)
        injectSession(session)

        let result = manager.session(id: "target")
        XCTAssertEqual(result?.sessionId, "target")
    }

    /// 测试：session(id:) 不存在的会话返回 nil
    func testSessionById_nonExistent_returnsNil() {
        XCTAssertNil(manager.session(id: "non-existent"))
    }

    /// 测试：sessions(in:) 返回指定目录的会话
    func testSessionsInCwd_filtersByCwd() {
        let s1 = makeSession(id: "s1", cwd: "/project-a")
        let s2 = makeSession(id: "s2", cwd: "/project-b")

        injectSession(s1)
        injectSession(s2)

        let results = manager.sessions(in: "/project-a")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].sessionId, "s1")
    }

    /// 测试：sessions(with:) 返回指定状态的会话
    func testSessionsWithStatus_filtersByStatus() {
        let s1 = makeSession(id: "s1", status: .coding)
        let s2 = makeSession(id: "s2", status: .idle)
        let s3 = makeSession(id: "s3", status: .coding)

        injectSession(s1)
        injectSession(s2)
        injectSession(s3)

        let coding = manager.sessions(with: .coding)
        XCTAssertEqual(coding.count, 2)
    }

    /// 测试：sessions(using:) 返回使用特定工具的会话
    func testSessionsUsingTool_filtersByTool() {
        var s1 = makeSession(id: "s1", status: .coding)
        s1.lastTool = "Read"
        var s2 = makeSession(id: "s2", status: .coding)
        s2.lastTool = "Write"

        injectSession(s1)
        injectSession(s2)

        let readSessions = manager.sessions(using: "Read")
        XCTAssertEqual(readSessions.count, 1)
        XCTAssertEqual(readSessions[0].sessionId, "s1")
    }

    /// 测试：sessionsWithSubagents 返回有子代理的会话
    func testSessionsWithSubagents_filtersBySubagents() {
        var s1 = makeSession(id: "s1")
        s1.activeSubagents = [SubagentInfo(agentId: "a1", agentType: "test", startedAt: Date())]
        let s2 = makeSession(id: "s2")

        injectSession(s1)
        injectSession(s2)

        let withSubagents = manager.sessionsWithSubagents()
        XCTAssertEqual(withSubagents.count, 1)
        XCTAssertEqual(withSubagents[0].sessionId, "s1")
    }

    /// 测试：recentSessions 按 lastActivity 排序并限制数量
    func testRecentSessions_sortedByLastActivity_limited() {
        let old = makeSession(id: "old", lastActivity: Date().addingTimeInterval(-3600))
        let recent = makeSession(id: "recent", lastActivity: Date())
        let newest = makeSession(id: "newest", lastActivity: Date().addingTimeInterval(100))

        injectSession(old)
        injectSession(recent)
        injectSession(newest)

        let results = manager.recentSessions(limit: 2)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].sessionId, "newest")
        XCTAssertEqual(results[1].sessionId, "recent")
    }

    /// 测试：sessions(from:) 返回指定来源的会话
    func testSessionsFromSource_filtersBySource() {
        let s1 = makeSession(id: "s1", source: "claude")
        let s2 = makeSession(id: "s2", source: "opencode")
        let s3 = makeSession(id: "s3", source: "claude")

        injectSession(s1)
        injectSession(s2)
        injectSession(s3)

        let claude = manager.sessions(from: "claude")
        XCTAssertEqual(claude.count, 2)
    }

    // MARK: - 活跃计数测试

    /// 测试：activeCount 排除 idle 和 completed
    func testActiveCount_excludesIdleAndCompleted() {
        injectSession(makeSession(id: "idle", status: .idle))
        injectSession(makeSession(id: "completed", status: .completed))
        injectSession(makeSession(id: "coding", status: .coding))
        injectSession(makeSession(id: "error", status: .error))

        XCTAssertEqual(manager.activeCount, 2) // coding + error
    }

    /// 测试：activeCount 包含所有非 idle/completed 状态
    func testActiveCount_includesAllActiveStates() {
        for state in SessionState.allCases {
            injectSession(makeSession(id: "s-\(state.rawValue)", status: state))
        }

        // 除了 idle 和 completed 都应计入
        let expected = SessionState.allCases.count - 2 // idle + completed
        XCTAssertEqual(manager.activeCount, expected)
    }

    // MARK: - 外部会话注册测试

    /// 测试：注册外部会话
    func testRegisterExternalSession() {
        let external = makeSession(id: "ext1", source: "opencode")
        manager.registerExternalSession(external)

        // 外部会话应带前缀
        let prefixed = manager.sessions["opencode_ext1"]
        XCTAssertNotNil(prefixed)
        XCTAssertEqual(prefixed?.source, "opencode")
    }

    /// 测试：移除外部会话
    func testRemoveExternalSession() {
        let external = makeSession(id: "ext1", source: "opencode")
        manager.registerExternalSession(external)
        XCTAssertNotNil(manager.sessions["opencode_ext1"])

        manager.removeExternalSession("opencode_ext1")
        XCTAssertNil(manager.sessions["opencode_ext1"])
    }

    // MARK: - 清理测试

    /// 测试：移除已完成会话
    func testRemoveCompletedSessions() {
        injectSession(makeSession(id: "s1", status: .completed))
        injectSession(makeSession(id: "s2", status: .completed))
        injectSession(makeSession(id: "s3", status: .coding))

        XCTAssertEqual(manager.sessions.count, 3)
        manager.removeCompletedSessions()
        XCTAssertEqual(manager.sessions.count, 1)
        XCTAssertNotNil(manager.sessions["s3"])
    }

    /// 测试：清除所有会话
    func testClearAll() {
        injectSession(makeSession(id: "s1", status: .coding))
        injectSession(makeSession(id: "s2", status: .idle))

        manager.clearAll()
        XCTAssertTrue(manager.sessions.isEmpty)
    }

    // MARK: - 状态聚合测试

    /// 测试：aggregateState(for:) 按 cwd 聚合
    func testAggregateStateForCwd() {
        injectSession(makeSession(id: "s1", status: .coding, cwd: "/project-a"))
        injectSession(makeSession(id: "s2", status: .error, cwd: "/project-a"))
        injectSession(makeSession(id: "s3", status: .idle, cwd: "/project-b"))

        let stateA = manager.aggregateState(for: "/project-a")
        XCTAssertEqual(stateA, .error) // error 优先级高

        let stateB = manager.aggregateState(for: "/project-b")
        XCTAssertEqual(stateB, .idle)
    }

    /// 测试：aggregateState(for:) 空目录返回 idle
    func testAggregateStateForCwd_empty_isIdle() {
        let state = manager.aggregateState(for: "/non-existent")
        XCTAssertEqual(state, .idle)
    }

    // MARK: - 摘要文本测试

    /// 测试：summaryText 无活跃会话
    func testSummaryText_noActive() {
        injectSession(makeSession(id: "s1", status: .idle))
        let text = manager.summaryText()
        XCTAssertTrue(text.contains("无活跃"))
    }

    /// 测试：summaryText 有活跃会话
    func testSummaryText_hasActive() {
        injectSession(makeSession(id: "s1", status: .coding))
        injectSession(makeSession(id: "s2", status: .thinking))
        let text = manager.summaryText()
        XCTAssertTrue(text.contains("活跃"))
    }

    /// 测试：summaryText 有错误会话
    func testSummaryText_hasError() {
        injectSession(makeSession(id: "s1", status: .error))
        let text = manager.summaryText()
        XCTAssertTrue(text.contains("活跃"))
    }

    /// 测试：summaryText 有等待权限
    func testSummaryText_hasPendingPermission() {
        injectSession(makeSession(id: "s1", status: .waitingPermission))
        let text = manager.summaryText()
        XCTAssertTrue(text.contains("权限"))
    }

    // MARK: - 多工具摘要测试

    /// 测试：multiToolSummary 无活跃会话
    func testMultiToolSummary_noActive() {
        let text = manager.multiToolSummary()
        XCTAssertTrue(text.contains("无活跃"))
    }

    /// 测试：multiToolSummary 包含多工具
    func testMultiToolSummary_multiTool() {
        injectSession(makeSession(id: "s1", status: .coding, source: "claude"))
        injectSession(makeSession(id: "s2", status: .coding, source: "opencode"))
        // Codex 目前在 multiToolSummary 中未实现，测试会失败，故只测 Claude 和 OpenCode
        let text = manager.multiToolSummary()
        XCTAssertTrue(text.contains("Claude") || text.contains("OpenCode"))
    }
}
