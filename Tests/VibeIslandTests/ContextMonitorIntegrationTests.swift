import XCTest
import Foundation
@testable import VibeIsland

/// 上下文监控集成测试
/// 验证：PreCompact 事件 -> ContextMonitor 解析 -> 阈值警告触发 -> 快照更新
@MainActor
final class ContextMonitorIntegrationTests: XCTestCase {

    // MARK: - 辅助方法

    /// 创建测试用会话
    private func makeSession(
        id: String,
        status: SessionState = .idle,
        cwd: String = "/tmp/project",
        notificationMessage: String? = nil,
        contextUsage: Double? = nil,
        contextTokensUsed: Int? = nil,
        contextTokensTotal: Int? = nil
    ) -> Session {
        Session(
            sessionId: id,
            cwd: cwd,
            status: status,
            lastActivity: Date(),
            notificationMessage: notificationMessage,
            contextUsage: contextUsage,
            contextTokensUsed: contextTokensUsed,
            contextTokensTotal: contextTokensTotal
        )
    }

    var monitor: ContextMonitor!
    var sessionManager: SessionManager!

    override func setUp() async throws {
        try await super.setUp()
        monitor = ContextMonitor.shared
        monitor.clearAll()
        sessionManager = SessionManager.makeForTesting()
    }

    override func tearDown() async throws {
        monitor.clearAll()
        sessionManager.stop()
        sessionManager = nil
        try await super.tearDown()
    }

    // MARK: - PreCompact 事件解析测试

    /// 测试：PreCompact 事件带标准英文格式消息，ContextMonitor 正确解析
    func testPreCompact_englishFormat_parsedCorrectly() {
        let session = makeSession(
            id: "precompact-1",
            status: .compacting,
            notificationMessage: "Context usage: 85% (170000/200000 tokens)"
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["precompact-1"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.85, accuracy: 0.01)
        XCTAssertEqual(snapshot?.tokensUsed, 170000)
        XCTAssertEqual(snapshot?.tokensTotal, 200000)
    }

    /// 测试：PreCompact 事件带中文格式消息，ContextMonitor 正确解析
    func testPreCompact_chineseFormat_parsedCorrectly() {
        let session = makeSession(
            id: "precompact-2",
            status: .compacting,
            notificationMessage: "上下文使用: 90% (180000/200000 tokens)"
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["precompact-2"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.90, accuracy: 0.01)
        XCTAssertEqual(snapshot?.tokensUsed, 180000)
        XCTAssertEqual(snapshot?.tokensTotal, 200000)
    }

    /// 测试：PreCompact 事件仅含百分比（无 token 数据）
    func testPreCompact_percentageOnly_parsedCorrectly() {
        let session = makeSession(
            id: "precompact-3",
            status: .compacting,
            notificationMessage: "Context usage: 60%"
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["precompact-3"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.60, accuracy: 0.01)
        XCTAssertNil(snapshot?.tokensUsed)
        XCTAssertNil(snapshot?.tokensTotal)
    }

    /// 测试：PreCompact 事件消息不匹配时，不创建快照
    func testPreCompact_nonMatchingMessage_noSnapshot() {
        monitor.clearAll()
        let session = makeSession(
            id: "precompact-4",
            status: .compacting,
            notificationMessage: "Some random notification message"
        )

        monitor.handleSessionUpdate(session)

        // 不匹配的消息不应创建快照
        XCTAssertNil(monitor.snapshots["precompact-4"])
    }

    /// 测试：非 PreCompact 状态但 notificationMessage 包含使用率，也能解析
    func testNonCompactingStatus_withUsageMessage_parsed() {
        let session = makeSession(
            id: "noncompact-1",
            status: .coding, // 不是 compacting 状态
            notificationMessage: "Context usage: 75% (150000/200000 tokens)"
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["noncompact-1"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.75, accuracy: 0.01)
    }

    // MARK: - Session.contextUsage 字段同步测试

    /// 测试：Session 的 contextUsage 字段同步到 ContextMonitor 快照
    func testSessionContextUsageField_syncedToMonitor() {
        let session = makeSession(
            id: "sync-1",
            status: .coding,
            contextUsage: 0.72,
            contextTokensUsed: 144000,
            contextTokensTotal: 200000
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["sync-1"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.72, accuracy: 0.01)
        XCTAssertEqual(snapshot?.tokensUsed, 144000)
        XCTAssertEqual(snapshot?.tokensTotal, 200000)
    }

    /// 测试：notificationMessage 优先级高于 contextUsage 字段
    func testNotificationMessage_takesPrecedenceOverContextUsageField() {
        let session = makeSession(
            id: "precedence-1",
            status: .compacting,
            notificationMessage: "Context usage: 90%", // 90%
            contextUsage: 0.50 // 50%
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["precedence-1"]
        XCTAssertNotNil(snapshot)
        // notificationMessage 中的 90% 应覆盖 contextUsage 字段的 50%
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.90, accuracy: 0.01)
    }

    // MARK: - 阈值警告触发测试

    /// 测试：使用率低于警告阈值时，hasWarning 为 false
    func testBelowWarningThreshold_noWarning() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "safe-1", usage: 0.50)
        monitor.setContextUsage(sessionId: "safe-2", usage: 0.79)

        XCTAssertFalse(monitor.hasWarning)
        XCTAssertFalse(monitor.shouldFlashWarning)
    }

    /// 测试：使用率等于警告阈值时，hasWarning 为 true
    func testAtWarningThreshold_warningTriggered() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "warn-1", usage: 0.80)

        XCTAssertTrue(monitor.hasWarning)
        XCTAssertTrue(monitor.shouldFlashWarning)
    }

    /// 测试：使用率略高于警告阈值时，hasWarning 为 true
    func testAboveWarningThreshold_warningTriggered() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "warn-2", usage: 0.85)

        XCTAssertTrue(monitor.hasWarning)
    }

    /// 测试：使用率低于危险阈值但高于警告阈值时，hasCritical 为 false
    func testBelowCriticalThreshold_noCritical() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "warn-only", usage: 0.90)

        XCTAssertTrue(monitor.hasWarning)
        XCTAssertFalse(monitor.hasCritical)
    }

    /// 测试：使用率等于危险阈值时，hasCritical 为 true
    func testAtCriticalThreshold_criticalTriggered() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "critical-1", usage: 0.95)

        XCTAssertTrue(monitor.hasCritical)
        XCTAssertTrue(monitor.hasWarning) // 危险时警告也应为 true
        XCTAssertTrue(monitor.shouldFlashWarning)
    }

    /// 测试：使用率超过危险阈值时，hasCritical 为 true
    func testAboveCriticalThreshold_criticalTriggered() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "critical-2", usage: 0.99)

        XCTAssertTrue(monitor.hasCritical)
        XCTAssertTrue(monitor.hasWarning)
    }

    /// 测试：多个会话中任一超过阈值即触发警告
    func testMultipleSessions_anyExceedingTriggersWarning() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "safe", usage: 0.50)
        monitor.setContextUsage(sessionId: "warning", usage: 0.85)
        monitor.setContextUsage(sessionId: "low", usage: 0.30)

        XCTAssertTrue(monitor.hasWarning)
    }

    /// 测试：多个会话中任一超过危险阈值即触发危险
    func testMultipleSessions_anyExceedingTriggersCritical() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "safe", usage: 0.50)
        monitor.setContextUsage(sessionId: "warning", usage: 0.85)
        monitor.setContextUsage(sessionId: "critical", usage: 0.96)

        XCTAssertTrue(monitor.hasCritical)
    }

    // MARK: - 快照更新验证

    /// 测试：连续更新同一会话的使用率，快照应反映最新值
    func testRepeatedUpdates_snapshotReflectsLatest() {
        monitor.clearAll()

        monitor.setContextUsage(sessionId: "update-1", usage: 0.50)
        XCTAssertEqual(monitor.snapshots["update-1"]?.usageRatio ?? 0, 0.50, accuracy: 0.01)

        monitor.setContextUsage(sessionId: "update-1", usage: 0.75)
        XCTAssertEqual(monitor.snapshots["update-1"]?.usageRatio ?? 0, 0.75, accuracy: 0.01)

        monitor.setContextUsage(sessionId: "update-1", usage: 0.90)
        XCTAssertEqual(monitor.snapshots["update-1"]?.usageRatio ?? 0, 0.90, accuracy: 0.01)
    }

    /// 测试：topSnapshot 始终返回使用率最高的会话
    func testTopSnapshot_alwaysHighestUsage() {
        monitor.clearAll()

        monitor.setContextUsage(sessionId: "low", usage: 0.30)
        XCTAssertEqual(monitor.topSnapshot?.sessionId, "low")

        monitor.setContextUsage(sessionId: "medium", usage: 0.65)
        XCTAssertEqual(monitor.topSnapshot?.sessionId, "medium")

        monitor.setContextUsage(sessionId: "high", usage: 0.92)
        XCTAssertEqual(monitor.topSnapshot?.sessionId, "high")

        // 降低最高值后，top 应变为次高
        monitor.setContextUsage(sessionId: "high", usage: 0.40)
        XCTAssertEqual(monitor.topSnapshot?.sessionId, "medium")
    }

    /// 测试：清除单个会话快照后，topSnapshot 正确更新
    func testClearSingleSnapshot_topSnapshotUpdated() {
        monitor.clearAll()

        monitor.setContextUsage(sessionId: "s1", usage: 0.90)
        monitor.setContextUsage(sessionId: "s2", usage: 0.70)

        XCTAssertEqual(monitor.topSnapshot?.sessionId, "s1")

        monitor.clearSnapshot(for: "s1")

        XCTAssertEqual(monitor.topSnapshot?.sessionId, "s2")
    }

    /// 测试：清除所有快照后状态正确重置
    func testClearAll_snapshotsReset() {
        monitor.setContextUsage(sessionId: "s1", usage: 0.50)
        monitor.setContextUsage(sessionId: "s2", usage: 0.85)

        XCTAssertTrue(monitor.hasWarning)

        monitor.clearAll()

        XCTAssertTrue(monitor.snapshots.isEmpty)
        XCTAssertNil(monitor.topSnapshot)
        XCTAssertFalse(monitor.hasWarning)
        XCTAssertFalse(monitor.hasCritical)
    }

    // MARK: - 端到端数据流测试

    /// 测试：完整 PreCompact 事件流 -> 解析 -> 警告触发
    func testEndToEnd_preCompactToWarning() {
        monitor.clearAll()

        // 第一步：会话开始，无上下文使用数据
        var session = makeSession(id: "e2e-1", status: .thinking)
        monitor.handleSessionUpdate(session)
        XCTAssertNil(monitor.snapshots["e2e-1"])

        // 第二步：开始编码，上下文使用率较低
        session = makeSession(
            id: "e2e-1",
            status: .coding,
            contextUsage: 0.40,
            contextTokensUsed: 80000,
            contextTokensTotal: 200000
        )
        monitor.handleSessionUpdate(session)

        let snapshot1 = monitor.snapshots["e2e-1"]
        XCTAssertNotNil(snapshot1)
        XCTAssertEqual(snapshot1?.usageRatio ?? 0, 0.40, accuracy: 0.01)
        XCTAssertFalse(monitor.hasWarning)

        // 第三步：触发 PreCompact，使用率达到警告阈值
        session = makeSession(
            id: "e2e-1",
            status: .compacting,
            notificationMessage: "Context usage: 82% (164000/200000 tokens)"
        )
        monitor.handleSessionUpdate(session)

        let snapshot2 = monitor.snapshots["e2e-1"]
        XCTAssertNotNil(snapshot2)
        XCTAssertEqual(snapshot2?.usageRatio ?? 0, 0.82, accuracy: 0.01)
        XCTAssertEqual(snapshot2?.tokensUsed, 164000)
        XCTAssertTrue(monitor.hasWarning)
        XCTAssertFalse(monitor.hasCritical)
    }

    /// 测试：PreCompact 事件流 -> 使用率持续上升 -> 危险阈值触发
    func testEndToEnd_usageRisingToCritical() {
        monitor.clearAll()

        // 第一阶段：60% 使用率
        var session = makeSession(
            id: "e2e-2",
            status: .coding,
            notificationMessage: "Context usage: 60%"
        )
        monitor.handleSessionUpdate(session)
        XCTAssertFalse(monitor.hasWarning)

        // 第二阶段：85% 使用率（警告）
        session = makeSession(
            id: "e2e-2",
            status: .compacting,
            notificationMessage: "Context usage: 85% (170000/200000 tokens)"
        )
        monitor.handleSessionUpdate(session)
        XCTAssertTrue(monitor.hasWarning)
        XCTAssertFalse(monitor.hasCritical)

        // 第三阶段：96% 使用率（危险）
        session = makeSession(
            id: "e2e-2",
            status: .compacting,
            notificationMessage: "Context usage: 96% (192000/200000 tokens)"
        )
        monitor.handleSessionUpdate(session)
        XCTAssertTrue(monitor.hasWarning)
        XCTAssertTrue(monitor.hasCritical)
        XCTAssertTrue(monitor.shouldFlashWarning)

        // 验证快照数据
        let finalSnapshot = monitor.snapshots["e2e-2"]
        XCTAssertNotNil(finalSnapshot)
        XCTAssertEqual(finalSnapshot?.usageRatio ?? 0, 0.96, accuracy: 0.01)
        XCTAssertEqual(finalSnapshot?.tokensRemaining, 8000) // 200000 - 192000
    }

    // MARK: - ContextUsageSnapshot 属性验证

    /// 测试：usagePercent 计算正确
    func testSnapshot_usagePercent() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "test",
            usageRatio: 0.857,
            tokensUsed: nil,
            tokensTotal: nil,
            timestamp: Date()
        )
        XCTAssertEqual(snapshot.usagePercent, 85) // Int(0.857 * 100) = 85
    }

    /// 测试：tokensRemaining 计算正确
    func testSnapshot_tokensRemaining() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "test",
            usageRatio: 0.75,
            tokensUsed: 150000,
            tokensTotal: 200000,
            timestamp: Date()
        )
        XCTAssertEqual(snapshot.tokensRemaining, 50000)
    }

    /// 测试：tokensRemaining 不会为负数
    func testSnapshot_tokensRemaining_nonNegative() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "test",
            usageRatio: 1.0,
            tokensUsed: 250000, // 超过 total
            tokensTotal: 200000,
            timestamp: Date()
        )
        XCTAssertEqual(snapshot.tokensRemaining, 0) // max(0, -50000) = 0
    }

    /// 测试：无 token 数据时 tokensRemaining 为 nil
    func testSnapshot_tokensRemaining_noData() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "test",
            usageRatio: 0.50,
            tokensUsed: nil,
            tokensTotal: nil,
            timestamp: Date()
        )
        XCTAssertNil(snapshot.tokensRemaining)
    }

    /// 测试：isWarning 和 isCritical 属性正确
    func testSnapshot_warningAndCriticalProperties() {
        let safe = ContextUsageSnapshot(sessionId: "s", usageRatio: 0.50, tokensUsed: nil, tokensTotal: nil, timestamp: Date())
        XCTAssertFalse(safe.isWarning)
        XCTAssertFalse(safe.isCritical)

        let warning = ContextUsageSnapshot(sessionId: "s", usageRatio: 0.80, tokensUsed: nil, tokensTotal: nil, timestamp: Date())
        XCTAssertTrue(warning.isWarning)
        XCTAssertFalse(warning.isCritical)

        let critical = ContextUsageSnapshot(sessionId: "s", usageRatio: 0.95, tokensUsed: nil, tokensTotal: nil, timestamp: Date())
        XCTAssertTrue(critical.isWarning)
        XCTAssertTrue(critical.isCritical)
    }

    // MARK: - 边界情况测试

    /// 测试：使用率为 0 时不触发警告
    func testZeroUsage_noWarning() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "zero", usage: 0.0)
        XCTAssertFalse(monitor.hasWarning)
        XCTAssertFalse(monitor.hasCritical)
    }

    /// 测试：使用率为 1.0（100%）时触发危险
    func testFullUsage_critical() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "full", usage: 1.0)
        XCTAssertTrue(monitor.hasCritical)
        XCTAssertTrue(monitor.hasWarning)
    }

    /// 测试：手动设置使用率超过 1.0 时被截断
    func testSetContextUsage_clampedMax() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "overflow", usage: 1.5)
        XCTAssertEqual(monitor.snapshots["overflow"]?.usageRatio ?? 0, 1.0, accuracy: 0.01)
    }

    /// 测试：手动设置使用率低于 0 时被截断
    func testSetContextUsage_clampedMin() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "negative", usage: -0.3)
        XCTAssertEqual(monitor.snapshots["negative"]?.usageRatio ?? 0, 0.0, accuracy: 0.01)
    }

    /// 测试：nil notificationMessage 不崩溃
    func testNilNotificationMessage_noCrash() {
        monitor.clearAll()
        let session = makeSession(
            id: "nil-msg",
            status: .coding,
            notificationMessage: nil
        )

        XCTAssertNoThrow(monitor.handleSessionUpdate(session))
    }

    /// 测试：空 notificationMessage 不创建快照
    func testEmptyNotificationMessage_noSnapshot() {
        monitor.clearAll()
        let session = makeSession(
            id: "empty-msg",
            status: .compacting,
            notificationMessage: ""
        )

        monitor.handleSessionUpdate(session)
        XCTAssertNil(monitor.snapshots["empty-msg"])
    }
}
