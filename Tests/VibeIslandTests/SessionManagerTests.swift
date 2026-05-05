import XCTest
@testable import VibeIsland

@MainActor
final class SessionManagerTests: XCTestCase {

    private var manager: SessionManager!

    override func setUp() {
        super.setUp()
        manager = SessionManager.makeForTesting()
    }

    override func tearDown() {
        manager.clearSessionsForTesting()
        manager = nil
        super.tearDown()
    }

    // MARK: - 辅助方法

    private func makeSession(
        id: String,
        status: SessionState = .idle,
        source: String? = nil,
        lastActivity: Date = Date(),
        cwd: String = "/tmp"
    ) -> Session {
        Session(
            sessionId: id,
            cwd: cwd,
            status: status,
            lastActivity: lastActivity,
            source: source
        )
    }

    // MARK: - 初始状态

    func testInitialSessionsEmpty() {
        XCTAssertTrue(manager.sortedSessions.isEmpty)
        XCTAssertEqual(manager.trackedSessionState, .idle)
    }

    func testInitialTrackingModeIsAuto() {
        XCTAssertTrue(manager.trackingMode.isAuto)
    }

    // MARK: - 会话注入/移除

    func testInjectSession_appearsInAllSessions() {
        let session = makeSession(id: "s1", status: .coding)
        manager.injectSessionForTesting(session)

        XCTAssertEqual(manager.allSessions.count, 1)
        XCTAssertEqual(manager.allSessions.first?.sessionId, "s1")
    }

    func testInjectMultipleSessions() {
        manager.injectSessionForTesting(makeSession(id: "s1"))
        manager.injectSessionForTesting(makeSession(id: "s2"))
        manager.injectSessionForTesting(makeSession(id: "s3"))

        XCTAssertEqual(manager.allSessions.count, 3)
    }

    func testRemoveSession_removesFromAllSessions() {
        manager.injectSessionForTesting(makeSession(id: "s1"))
        manager.injectSessionForTesting(makeSession(id: "s2"))
        manager.removeSessionForTesting("s1")

        XCTAssertEqual(manager.allSessions.count, 1)
        XCTAssertEqual(manager.allSessions.first?.sessionId, "s2")
    }

    func testRemoveNonexistentSession_doesNotCrash() {
        manager.removeSessionForTesting("nonexistent")
        XCTAssertTrue(manager.allSessions.isEmpty)
    }

    func testClearSessions_removesAll() {
        manager.injectSessionForTesting(makeSession(id: "s1"))
        manager.injectSessionForTesting(makeSession(id: "s2"))
        manager.clearSessionsForTesting()

        XCTAssertTrue(manager.allSessions.isEmpty)
        XCTAssertTrue(manager.sortedSessions.isEmpty)
    }

    // MARK: - 排序逻辑

    func testSortedSessions_sortedByLastActivityDescending() {
        let now = Date()
        let old = now.addingTimeInterval(-3600)
        let older = now.addingTimeInterval(-7200)

        manager.injectSessionForTesting(makeSession(id: "old", lastActivity: old))
        manager.injectSessionForTesting(makeSession(id: "newest", lastActivity: now))
        manager.injectSessionForTesting(makeSession(id: "oldest", lastActivity: older))

        let sorted = manager.sortedSessions
        XCTAssertEqual(sorted[0].sessionId, "newest")
        XCTAssertEqual(sorted[1].sessionId, "old")
        XCTAssertEqual(sorted[2].sessionId, "oldest")
    }

    // MARK: - 跟踪模式：auto

    func testAutoMode_trackedSessionIsFirstSorted() {
        let now = Date()
        let earlier = now.addingTimeInterval(-60)

        manager.injectSessionForTesting(makeSession(id: "older", lastActivity: earlier))
        manager.injectSessionForTesting(makeSession(id: "newer", lastActivity: now))

        XCTAssertEqual(manager.trackedSession?.sessionId, "newer")
    }

    func testAutoMode_trackedSessionStateReflectsFirstSession() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .coding))
        XCTAssertEqual(manager.trackedSessionState, .coding)
    }

    func testAutoMode_noSessions_returnsIdle() {
        XCTAssertEqual(manager.trackedSessionState, .idle)
    }

    // MARK: - 跟踪模式：manual

    func testManualMode_tracksPinnedSession() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .idle))
        manager.injectSessionForTesting(makeSession(id: "s2", status: .error))

        manager.setTrackingModeManual(sessionId: "s1")
        XCTAssertFalse(manager.trackingMode.isAuto)
        XCTAssertEqual(manager.pinnedSessionId, "s1")
        XCTAssertEqual(manager.trackedSession?.sessionId, "s1")
        XCTAssertEqual(manager.trackedSessionState, .idle)
    }

    func testManualMode_switchBackToAuto() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .idle))
        manager.setTrackingModeManual(sessionId: "s1")
        manager.setTrackingModeAuto()

        XCTAssertTrue(manager.trackingMode.isAuto)
        XCTAssertNil(manager.pinnedSessionId)
    }

    func testManualMode_nonexistentSession_returnsNil() {
        manager.setTrackingModeManual(sessionId: "missing")
        XCTAssertNil(manager.trackedSession)
        XCTAssertEqual(manager.trackedSessionState, .idle)
    }

    // MARK: - 聚合状态

    func testAggregateState_emptyIsIdle() {
        XCTAssertEqual(manager.aggregateState, .idle)
    }

    func testAggregateState_highestPriorityWins() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .completed))
        manager.injectSessionForTesting(makeSession(id: "s2", status: .error))
        manager.injectSessionForTesting(makeSession(id: "s3", status: .coding))

        // error(1) > coding(3) > completed(6)
        XCTAssertEqual(manager.aggregateState, .error)
    }

    func testAggregateState_waitingPermission_highestPriority() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .coding))
        manager.injectSessionForTesting(makeSession(id: "s2", status: .waitingPermission))

        XCTAssertEqual(manager.aggregateState, .waitingPermission)
    }

    // MARK: - 状态回调

    func testOnAggregateStateChanged_callbackCanBeSet() {
        var callbackFired = false
        manager.onAggregateStateChanged = { _, _ in
            callbackFired = true
        }
        // injectSessionForTesting 不触发回调（仅 start() 路径触发）
        // 验证回调可以被设置且不崩溃
        XCTAssertFalse(callbackFired)
    }

    // MARK: - Claude Code 会话检测

    func testHasClaudeCodeSessions_sourceNil() {
        manager.injectSessionForTesting(makeSession(id: "s1", source: nil))
        XCTAssertTrue(manager.hasClaudeCodeSessions)
    }

    func testHasClaudeCodeSessions_sourceClaude() {
        manager.injectSessionForTesting(makeSession(id: "s1", source: "claude"))
        XCTAssertTrue(manager.hasClaudeCodeSessions)
    }

    func testHasClaudeCodeSessions_sourceOpenCode_isFalse() {
        manager.injectSessionForTesting(makeSession(id: "s1", source: "opencode"))
        XCTAssertFalse(manager.hasClaudeCodeSessions)
    }

    func testHasClaudeCodeSessions_empty_isFalse() {
        XCTAssertFalse(manager.hasClaudeCodeSessions)
    }

    // MARK: - OpenCode 会话过滤

    func testSessionsFromSource_filtersCorrectly() {
        manager.injectSessionForTesting(makeSession(id: "s1", source: "opencode"))
        manager.injectSessionForTesting(makeSession(id: "s2", source: "claude"))
        manager.injectSessionForTesting(makeSession(id: "s3", source: "opencode"))

        let opencodeSessions = manager.sessions(from: "opencode")
        XCTAssertEqual(opencodeSessions.count, 2)
        XCTAssertTrue(opencodeSessions.allSatisfy { $0.source == "opencode" })
    }

    func testSessionsFromSource_noMatch_returnsEmpty() {
        manager.injectSessionForTesting(makeSession(id: "s1", source: "claude"))
        XCTAssertTrue(manager.sessions(from: "opencode").isEmpty)
    }

    // MARK: - sessionStatus 协议方法

    func testSessionStatus_returnsSessionStatus() {
        let session = makeSession(id: "s1", status: .thinking)
        XCTAssertEqual(manager.sessionStatus(session), .thinking)
    }

    // MARK: - activeCount

    func testActiveCount_excludesIdleAndCompleted() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .idle))
        manager.injectSessionForTesting(makeSession(id: "s2", status: .completed))
        manager.injectSessionForTesting(makeSession(id: "s3", status: .coding))
        manager.injectSessionForTesting(makeSession(id: "s4", status: .error))

        XCTAssertEqual(manager.activeCount, 2)
    }

    // MARK: - hasPendingPermission

    func testHasPendingPermission_trueWhenPresent() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .waitingPermission))
        XCTAssertTrue(manager.hasPendingPermission)
    }

    func testHasPendingPermission_falseWhenAbsent() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .coding))
        XCTAssertFalse(manager.hasPendingPermission)
    }

    // MARK: - hasError

    func testHasError_trueWhenPresent() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .error))
        XCTAssertTrue(manager.hasError)
    }

    func testHasError_falseWhenAbsent() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .coding))
        XCTAssertFalse(manager.hasError)
    }
}
