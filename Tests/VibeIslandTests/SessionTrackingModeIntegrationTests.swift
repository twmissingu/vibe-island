import XCTest
import Foundation
@testable import VibeIsland

/// 会话跟踪模式集成测试
/// 验证：自动模式 -> 最高优先级会话
///      手动模式 -> 固定会话
///      模式切换验证
///      持久化验证
@MainActor
final class SessionTrackingModeIntegrationTests: XCTestCase {

    // MARK: - 辅助方法

    /// 创建测试用会话
    private func makeSession(
        id: String,
        status: SessionState = .idle,
        cwd: String = "/tmp/project",
        lastActivity: Date = Date()
    ) -> Session {
        Session(
            sessionId: id,
            cwd: cwd,
            status: status,
            lastActivity: lastActivity
        )
    }

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

    // MARK: - 自动模式：最高优先级会话

    /// 测试：自动模式下无活跃会话时，trackedSession fallback 到最近活跃
    func testAutoMode_noActiveSessions_fallbackToRecent() {
        manager.setTrackingModeForTesting(.auto)

        let old = makeSession(id: "old", status: .idle, lastActivity: Date().addingTimeInterval(-3600))
        let recent = makeSession(id: "recent", status: .completed, lastActivity: Date())

        manager.injectSessionForTesting(old)
        manager.injectSessionForTesting(recent)

        let tracked = manager.trackedSession
        // 无活跃会话时 fallback 到最近活跃
        XCTAssertNotNil(tracked)
        XCTAssertEqual(tracked?.sessionId, "recent")
    }

    /// 测试：自动模式下有单个活跃会话时，trackedSession 返回该会话
    func testAutoMode_singleActiveSession_returnsIt() {
        manager.setTrackingModeForTesting(.auto)

        let coding = makeSession(id: "coding-1", status: .coding)
        manager.injectSessionForTesting(coding)

        let tracked = manager.trackedSession
        XCTAssertNotNil(tracked)
        XCTAssertEqual(tracked?.sessionId, "coding-1")
        XCTAssertEqual(tracked?.status, .coding)
    }

    /// 测试：自动模式下有多个活跃会话时，trackedSession 返回最高优先级
    func testAutoMode_multipleActiveSessions_returnsHighestPriority() {
        manager.setTrackingModeForTesting(.auto)

        let coding = makeSession(id: "coding", status: .coding)
        let error = makeSession(id: "error", status: .error)
        let thinking = makeSession(id: "thinking", status: .thinking)
        let waitingPermission = makeSession(id: "waiting", status: .waitingPermission)

        manager.injectSessionForTesting(coding)
        manager.injectSessionForTesting(error)
        manager.injectSessionForTesting(thinking)
        manager.injectSessionForTesting(waitingPermission)

        let tracked = manager.trackedSession
        XCTAssertNotNil(tracked)
        // waitingPermission 优先级最高 (0)
        XCTAssertEqual(tracked?.status, .waitingPermission)
        XCTAssertEqual(tracked?.sessionId, "waiting")
    }

    /// 测试：自动模式下过滤 idle 和 completed 会话
    func testAutoMode_filtersIdleAndCompleted() {
        manager.setTrackingModeForTesting(.auto)

        let idle = makeSession(id: "idle", status: .idle)
        let completed = makeSession(id: "completed", status: .completed)
        let coding = makeSession(id: "coding", status: .coding)

        manager.injectSessionForTesting(idle)
        manager.injectSessionForTesting(completed)
        manager.injectSessionForTesting(coding)

        let tracked = manager.trackedSession
        XCTAssertNotNil(tracked)
        // 只应返回 coding（活跃会话）
        XCTAssertEqual(tracked?.status, .coding)
    }

    /// 测试：自动模式下所有状态优先级排序正确
    func testAutoMode_priorityOrder_allStates() {
        manager.setTrackingModeForTesting(.auto)

        for state in SessionState.allCases {
            if state != .idle && state != .completed {
                manager.injectSessionForTesting(makeSession(id: state.rawValue, status: state))
            }
        }

        let tracked = manager.trackedSession
        XCTAssertNotNil(tracked)
        // waitingPermission 优先级最高
        XCTAssertEqual(tracked?.status, .waitingPermission)
    }

    /// 测试：自动模式下新增高优先级会话后，trackedSession 立即切换
    func testAutoMode_newHigherPrioritySession_switchesImmediately() {
        manager.setTrackingModeForTesting(.auto)

        // 初始只有 coding 会话
        let coding = makeSession(id: "coding", status: .coding)
        manager.injectSessionForTesting(coding)
        XCTAssertEqual(manager.trackedSession?.status, .coding)

        // 新增 error 会话
        let error = makeSession(id: "error", status: .error)
        manager.injectSessionForTesting(error)

        // trackedSession 应立即切换到 error
        XCTAssertEqual(manager.trackedSession?.status, .error)
    }

    // MARK: - 手动模式：固定会话

    /// 测试：手动模式下返回固定的会话
    func testManualMode_returnsPinnedSession() {
        let session = makeSession(id: "pinned-1", status: .coding)
        manager.injectSessionForTesting(session)

        manager.setTrackingModeForTesting(.manual(sessionId: "pinned-1"))

        let tracked = manager.trackedSession
        XCTAssertNotNil(tracked)
        XCTAssertEqual(tracked?.sessionId, "pinned-1")
    }

    /// 测试：手动模式下固定 idle 会话也返回
    func testManualMode_pinnedIdleSession_returnsIt() {
        let idle = makeSession(id: "idle-pinned", status: .idle)
        manager.injectSessionForTesting(idle)

        manager.setTrackingModeForTesting(.manual(sessionId: "idle-pinned"))

        let tracked = manager.trackedSession
        XCTAssertNotNil(tracked)
        XCTAssertEqual(tracked?.sessionId, "idle-pinned")
        XCTAssertEqual(tracked?.status, .idle)
    }

    /// 测试：手动模式下固定不存在的会话时，trackedSession 为 nil
    func testManualMode_nonExistentSession_returnsNil() {
        manager.setTrackingModeForTesting(.manual(sessionId: "does-not-exist"))

        XCTAssertNil(manager.trackedSession)
    }

    /// 测试：手动模式下固定会话被删除后，trackedSession 为 nil
    func testManualMode_sessionDeleted_returnsNil() {
        let session = makeSession(id: "to-delete", status: .coding)
        manager.injectSessionForTesting(session)

        manager.setTrackingModeForTesting(.manual(sessionId: "to-delete"))
        XCTAssertNotNil(manager.trackedSession)

        // 删除会话
        manager.removeSessionForTesting( "to-delete")

        XCTAssertNil(manager.trackedSession)
    }

    /// 测试：手动模式下 pinnedSessionId 属性正确
    func testManualMode_pinnedSessionId() {
        manager.setTrackingModeForTesting(.manual(sessionId: "pinned-id"))
        XCTAssertEqual(manager.pinnedSessionId, "pinned-id")
    }

    /// 测试：自动模式下 pinnedSessionId 为 nil
    func testAutoMode_pinnedSessionId_isNil() {
        manager.setTrackingModeForTesting(.auto)
        XCTAssertNil(manager.pinnedSessionId)
    }

    // MARK: - 模式切换验证

    /// 测试：从自动切换到手动模式
    func testToggleTrackingMode_autoToManual() {
        manager.setTrackingModeForTesting(.auto)

        let session = makeSession(id: "toggle-1", status: .coding)
        manager.injectSessionForTesting(session)

        manager.toggleTrackingMode()

        // 应切换到手动模式，固定当前 trackedSession
        if case .manual(let id) = manager.trackingMode {
            XCTAssertEqual(id, "toggle-1")
        } else {
            XCTFail("应切换到手动模式")
        }
    }

    /// 测试：从手动切换到自动模式
    func testToggleTrackingMode_manualToAuto() {
        manager.setTrackingModeForTesting(.manual(sessionId: "pinned"))

        manager.toggleTrackingMode()

        XCTAssertTrue(manager.trackingMode.isAuto)
        XCTAssertNil(manager.pinnedSessionId)
    }

    /// 测试：setTrackingModeAuto 方法正确设置
    func testSetTrackingModeAuto_correctSetting() {
        manager.setTrackingModeForTesting(.manual(sessionId: "pinned"))

        manager.setTrackingModeAuto()

        XCTAssertTrue(manager.trackingMode.isAuto)
        XCTAssertNil(manager.pinnedSessionId)
    }

    /// 测试：setTrackingModeManual 方法正确设置
    func testSetTrackingModeManual_correctSetting() {
        manager.setTrackingModeForTesting(.auto)

        manager.setTrackingModeManual(sessionId: "manual-session")

        if case .manual(let id) = manager.trackingMode {
            XCTAssertEqual(id, "manual-session")
        } else {
            XCTFail("应为手动模式")
        }
        XCTAssertEqual(manager.pinnedSessionId, "manual-session")
    }

    /// 测试：模式切换后 aggregateState 不受影响
    func testTrackingModeSwitch_aggregateStateUnchanged() {
        let coding = makeSession(id: "coding", status: .coding)
        let error = makeSession(id: "error", status: .error)
        manager.injectSessionForTesting(coding)
        manager.injectSessionForTesting(error)

        let stateBefore = manager.aggregateState
        XCTAssertEqual(stateBefore, .error)

        // 切换模式
        manager.setTrackingModeForTesting(.manual(sessionId: "coding"))
        let stateAfter = manager.aggregateState

        // aggregateState 不应受跟踪模式影响
        XCTAssertEqual(stateAfter, .error)
    }

    /// 测试：模式切换后 activeCount 不受影响
    func testTrackingModeSwitch_activeCountUnchanged() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .coding))
        manager.injectSessionForTesting(makeSession(id: "s2", status: .error))
        manager.injectSessionForTesting(makeSession(id: "s3", status: .idle))

        let countBefore = manager.activeCount
        XCTAssertEqual(countBefore, 2)

        manager.setTrackingModeForTesting(.manual(sessionId: "s1"))
        let countAfter = manager.activeCount

        XCTAssertEqual(countAfter, 2)
    }

    /// 测试：模式切换后 hasPendingPermission 不受影响
    func testTrackingModeSwitch_hasPendingPermissionUnchanged() {
        manager.injectSessionForTesting(makeSession(id: "waiting", status: .waitingPermission))

        manager.setTrackingModeForTesting(.auto)
        XCTAssertTrue(manager.hasPendingPermission)

        manager.setTrackingModeForTesting(.manual(sessionId: "waiting"))
        XCTAssertTrue(manager.hasPendingPermission)

        manager.setTrackingModeForTesting(.manual(sessionId: "non-existent"))
        // 即使 trackedSession 为 nil，sessions 中仍有 waitingPermission
        XCTAssertTrue(manager.hasPendingPermission)
    }

    // MARK: - 持久化验证

    /// 测试：TrackingMode 枚举的 isAuto 属性正确
    func testTrackingMode_isAuto_auto() {
        let mode: TrackingMode = .auto
        XCTAssertTrue(mode.isAuto)
    }

    /// 测试：TrackingMode 枚举的 isAuto 属性 - 手动模式
    func testTrackingMode_isAuto_manual() {
        let mode: TrackingMode = .manual(sessionId: "test")
        XCTAssertFalse(mode.isAuto)
    }

    /// 测试：TrackingMode 等价比较 - 自动模式
    func testTrackingMode_equatable_auto() {
        let mode1: TrackingMode = .auto
        let mode2: TrackingMode = .auto
        XCTAssertEqual(mode1, mode2)
    }

    /// 测试：TrackingMode 等价比较 - 手动模式相同 ID
    func testTrackingMode_equatable_manual_sameId() {
        let mode1: TrackingMode = .manual(sessionId: "session-1")
        let mode2: TrackingMode = .manual(sessionId: "session-1")
        XCTAssertEqual(mode1, mode2)
    }

    /// 测试：TrackingMode 等价比较 - 手动模式不同 ID
    func testTrackingMode_equatable_manual_differentId() {
        let mode1: TrackingMode = .manual(sessionId: "session-1")
        let mode2: TrackingMode = .manual(sessionId: "session-2")
        XCTAssertNotEqual(mode1, mode2)
    }

    /// 测试：TrackingMode 等价比较 - 自动与手动不同
    func testTrackingMode_equatable_autoVsManual() {
        let mode1: TrackingMode = .auto
        let mode2: TrackingMode = .manual(sessionId: "session-1")
        XCTAssertNotEqual(mode1, mode2)
    }

    // MARK: - 综合场景测试

    /// 测试：完整跟踪模式生命周期
    func testFullTrackingModeLifecycle() {
        // 初始状态：自动模式
        XCTAssertTrue(manager.trackingMode.isAuto)
        XCTAssertNil(manager.pinnedSessionId)

        // 添加会话
        let s1 = makeSession(id: "s1", status: .coding)
        let s2 = makeSession(id: "s2", status: .error)
        manager.injectSessionForTesting(s1)
        manager.injectSessionForTesting(s2)

        // 自动模式下 trackedSession 为最高优先级
        XCTAssertEqual(manager.trackedSession?.status, .error)

        // 切换到手动模式，固定 s1
        manager.setTrackingModeManual(sessionId: "s1")
        if case .manual(let id) = manager.trackingMode {
            XCTAssertEqual(id, "s1")
        }
        XCTAssertEqual(manager.trackedSession?.status, .coding) // 固定到 s1

        // 切换回自动模式
        manager.setTrackingModeAuto()
        XCTAssertTrue(manager.trackingMode.isAuto)
        XCTAssertEqual(manager.trackedSession?.status, .error) // 回到最高优先级

        // 移除 error 会话
        manager.removeSessionForTesting( "s2")
        XCTAssertEqual(manager.trackedSession?.status, .coding)
    }

    /// 测试：自动模式下 trackedSession 随会话状态变化动态更新
    func testAutoMode_trackedSessionDynamicUpdate() {
        manager.setTrackingModeForTesting(.auto)

        // 初始：只有 thinking 会话
        let thinking = makeSession(id: "thinking", status: .thinking)
        manager.injectSessionForTesting(thinking)
        XCTAssertEqual(manager.trackedSession?.status, .thinking)

        // 新增 coding 会话（优先级更高）
        let coding = makeSession(id: "coding", status: .coding)
        manager.injectSessionForTesting(coding)
        XCTAssertEqual(manager.trackedSession?.status, .coding)

        // thinking 变为 error（优先级最高）
        var updatedThinking = thinking
        updatedThinking = Session(
            sessionId: "thinking",
            cwd: thinking.cwd,
            status: .error,
            lastActivity: Date()
        )
        manager.injectSessionForTesting(updatedThinking)
        XCTAssertEqual(manager.trackedSession?.status, .error)

        // coding 完成
        var completedCoding = coding
        completedCoding = Session(
            sessionId: "coding",
            cwd: coding.cwd,
            status: .completed,
            lastActivity: Date()
        )
        manager.injectSessionForTesting(completedCoding)
        // error 仍为最高优先级
        XCTAssertEqual(manager.trackedSession?.status, .error)

        // error 也完成
        var completedError = updatedThinking
        completedError = Session(
            sessionId: "thinking",
            cwd: updatedThinking.cwd,
            status: .completed,
            lastActivity: Date()
        )
        manager.injectSessionForTesting(completedError)
        // 无活跃会话，fallback
        XCTAssertNotNil(manager.trackedSession)
    }

    /// 测试：手动模式下切换固定不同会话
    func testManualMode_switchPinnedSession() {
        let s1 = makeSession(id: "s1", status: .coding)
        let s2 = makeSession(id: "s2", status: .error)
        manager.injectSessionForTesting(s1)
        manager.injectSessionForTesting(s2)

        // 固定 s1
        manager.setTrackingModeManual(sessionId: "s1")
        XCTAssertEqual(manager.trackedSession?.sessionId, "s1")

        // 切换到 s2
        manager.setTrackingModeManual(sessionId: "s2")
        XCTAssertEqual(manager.trackedSession?.sessionId, "s2")
        XCTAssertEqual(manager.trackedSession?.status, .error)
    }

    /// 测试：sortedSessions 在模式切换后保持正确排序
    func testSortedSessions_afterModeSwitch() {
        let idle = makeSession(id: "idle", status: .idle)
        let coding = makeSession(id: "coding", status: .coding)
        let error = makeSession(id: "error", status: .error)

        manager.injectSessionForTesting(idle)
        manager.injectSessionForTesting(coding)
        manager.injectSessionForTesting(error)

        // 自动模式
        manager.setTrackingModeForTesting(.auto)
        let sortedAuto = manager.sortedSessions
        XCTAssertEqual(sortedAuto.first?.status, .error)
        XCTAssertEqual(sortedAuto.last?.status, .idle)

        // 手动模式
        manager.setTrackingModeForTesting(.manual(sessionId: "idle"))
        let sortedManual = manager.sortedSessions
        // sortedSessions 始终按优先级排序，不受跟踪模式影响
        XCTAssertEqual(sortedManual.first?.status, .error)
        XCTAssertEqual(sortedManual.last?.status, .idle)
    }

    // MARK: - summaryText 在模式切换下测试

    /// 测试：summaryText 在自动模式下正确反映聚合状态
    func testSummaryText_autoMode_reflectsAggregate() {
        manager.setTrackingModeForTesting(.auto)

        manager.injectSessionForTesting(makeSession(id: "s1", status: .coding))
        manager.injectSessionForTesting(makeSession(id: "s2", status: .thinking))

        let text = manager.summaryText()
        XCTAssertTrue(text.contains("2"))
        XCTAssertTrue(text.contains("活跃"))
    }

    /// 测试：summaryText 在手动模式下仍反映全局状态
    func testSummaryText_manualMode_reflectsGlobalState() {
        manager.injectSessionForTesting(makeSession(id: "s1", status: .coding))
        manager.injectSessionForTesting(makeSession(id: "s2", status: .error))

        manager.setTrackingModeForTesting(.manual(sessionId: "s1"))

        // summaryText 应反映全局状态，包括 error
        let text = manager.summaryText()
        // 由于有 error 会话，应包含警告
        XCTAssertTrue(text.contains("活跃"))
    }
}
