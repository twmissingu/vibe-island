import XCTest
import Foundation
@testable import VibeIsland

/// ContextMonitor 测试
/// 测试上下文监控服务的核心功能：PreCompact 事件解析、上下文使用率计算、警告/危险阈值触发等
@MainActor
final class ContextMonitorTests: XCTestCase {

    var monitor: ContextMonitor!

    override func setUp() async throws {
        try await super.setUp()
        monitor = ContextMonitor.shared
        // 清理残留数据
        monitor.clearAll()
    }

    override func tearDown() async throws {
        monitor.clearAll()
        try await super.tearDown()
    }

    // MARK: - 阈值常量测试

    /// 测试：警告阈值为 0.80
    func testWarningThreshold() {
        XCTAssertEqual(contextWarningThreshold, 0.80)
    }

    /// 测试：危险阈值为 0.95
    func testCriticalThreshold() {
        XCTAssertEqual(contextCriticalThreshold, 0.95)
    }

    // MARK: - ContextUsageSnapshot 测试

    /// 测试：创建快照基本属性
    func testContextUsageSnapshot_basicProperties() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "test-1",
            usageRatio: 0.75,
            tokensUsed: 150000,
            tokensTotal: 200000,
            timestamp: Date()
        )

        XCTAssertEqual(snapshot.sessionId, "test-1")
        XCTAssertEqual(snapshot.usageRatio, 0.75)
        XCTAssertEqual(snapshot.tokensUsed, 150000)
        XCTAssertEqual(snapshot.tokensTotal, 200000)
    }

    /// 测试：usagePercent 计算正确
    func testContextUsageSnapshot_usagePercent() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "s1",
            usageRatio: 0.85,
            tokensUsed: nil,
            tokensTotal: nil,
            timestamp: Date()
        )
        XCTAssertEqual(snapshot.usagePercent, 85)
    }

    /// 测试：usagePercent 0% 和 100%
    func testContextUsageSnapshot_usagePercent_bounds() {
        let zero = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.0,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertEqual(zero.usagePercent, 0)

        let full = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 1.0,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertEqual(full.usagePercent, 100)
    }

    /// 测试：tokensRemaining 计算正确
    func testContextUsageSnapshot_tokensRemaining() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "s1",
            usageRatio: 0.75,
            tokensUsed: 150000,
            tokensTotal: 200000,
            timestamp: Date()
        )
        XCTAssertEqual(snapshot.tokensRemaining, 50000)
    }

    /// 测试：tokensRemaining 无 token 数据时返回 nil
    func testContextUsageSnapshot_tokensRemaining_noData() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "s1",
            usageRatio: 0.5,
            tokensUsed: nil,
            tokensTotal: nil,
            timestamp: Date()
        )
        XCTAssertNil(snapshot.tokensRemaining)
    }

    /// 测试：tokensRemaining 不会为负数
    func testContextUsageSnapshot_tokensRemaining_nonNegative() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "s1",
            usageRatio: 1.0,
            tokensUsed: 250000,
            tokensTotal: 200000,
            timestamp: Date()
        )
        XCTAssertEqual(snapshot.tokensRemaining, 0) // max(0, -50000) = 0
    }

    /// 测试：isWarning 在超过警告阈值时为 true
    func testContextUsageSnapshot_isWarning() {
        let below = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.79,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertFalse(below.isWarning)

        let at = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.80,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(at.isWarning)

        let above = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.90,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(above.isWarning)
    }

    /// 测试：isCritical 在超过危险阈值时为 true
    func testContextUsageSnapshot_isCritical() {
        let below = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.94,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertFalse(below.isCritical)

        let at = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.95,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(at.isCritical)

        let above = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.99,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(above.isCritical)
    }

    /// 测试：ContextUsageSnapshot Equatable
    func testContextUsageSnapshot_equatable() {
        let now = Date()
        let s1 = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.5,
            tokensUsed: 100, tokensTotal: 200, timestamp: now
        )
        let s2 = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.5,
            tokensUsed: 100, tokensTotal: 200, timestamp: now
        )
        XCTAssertEqual(s1, s2)
    }

    // MARK: - 上下文监控服务测试

    /// 测试：初始 snapshots 为空
    func testInitialSnapshots_empty() {
        monitor.clearAll()
        XCTAssertTrue(monitor.snapshots.isEmpty)
    }

    /// 测试：初始 topSnapshot 为 nil
    func testInitialTopSnapshot_nil() {
        monitor.clearAll()
        XCTAssertNil(monitor.topSnapshot)
    }

    /// 测试：初始 hasWarning 为 false
    func testInitialHasWarning_false() {
        monitor.clearAll()
        XCTAssertFalse(monitor.hasWarning)
    }

    /// 测试：初始 hasCritical 为 false
    func testInitialHasCritical_false() {
        monitor.clearAll()
        XCTAssertFalse(monitor.hasCritical)
    }

    /// 测试：初始 shouldFlashWarning 为 false
    func testInitialShouldFlashWarning_false() {
        monitor.clearAll()
        XCTAssertFalse(monitor.shouldFlashWarning)
    }

    // MARK: - setContextUsage 测试

    /// 测试：手动设置上下文使用率
    func testSetContextUsage_setsSnapshot() {
        monitor.setContextUsage(
            sessionId: "test-1",
            usage: 0.75,
            tokensUsed: 150000,
            tokensTotal: 200000
        )

        let snapshot = monitor.snapshots["test-1"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.75)
        XCTAssertEqual(snapshot?.tokensUsed, 150000)
        XCTAssertEqual(snapshot?.tokensTotal, 200000)
    }

    /// 测试：设置使用率超过 1.0 被截断
    func testSetContextUsage_clampedMax() {
        monitor.setContextUsage(sessionId: "s1", usage: 1.5)
        XCTAssertEqual(monitor.snapshots["s1"]?.usageRatio, 1.0)
    }

    /// 测试：设置使用率低于 0 被截断
    func testSetContextUsage_clampedMin() {
        monitor.setContextUsage(sessionId: "s1", usage: -0.5)
        XCTAssertEqual(monitor.snapshots["s1"]?.usageRatio, 0.0)
    }

    // MARK: - 解析 PreCompact 事件测试

    /// 测试：解析标准英文格式 "Context usage: 85% (170000/200000 tokens)"
    func testParseContextUsage_englishFormat() {
        let session = Session(
            sessionId: "test-1",
            cwd: "/project",
            status: .compacting,
            notificationMessage: "Context usage: 85% (170000/200000 tokens)"
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["test-1"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.85, accuracy: 0.01)
        XCTAssertEqual(snapshot?.tokensUsed, 170000)
        XCTAssertEqual(snapshot?.tokensTotal, 200000)
    }

    /// 测试：解析中文格式 "上下文使用: 85% (170000/200000 tokens)"
    func testParseContextUsage_chineseFormat() {
        let session = Session(
            sessionId: "test-1",
            cwd: "/project",
            status: .compacting,
            notificationMessage: "上下文使用: 90% (180000/200000 tokens)"
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["test-1"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.90, accuracy: 0.01)
    }

    /// 测试：解析无 token 数据的格式 "Context usage: 50%"
    func testParseContextUsage_noTokenData() {
        let session = Session(
            sessionId: "test-1",
            cwd: "/project",
            status: .compacting,
            notificationMessage: "Context usage: 50%"
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["test-1"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.50, accuracy: 0.01)
        XCTAssertNil(snapshot?.tokensUsed)
        XCTAssertNil(snapshot?.tokensTotal)
    }

    /// 测试：解析不匹配的消息不创建快照
    func testParseContextUsage_noMatch() {
        monitor.clearAll()
        let session = Session(
            sessionId: "test-1",
            cwd: "/project",
            status: .coding,
            notificationMessage: "Some random message"
        )

        monitor.handleSessionUpdate(session)
        // 不匹配的消息不应创建快照（除非 session 有 contextUsage 字段）
        XCTAssertNil(monitor.snapshots["test-1"])
    }

    /// 测试：解析 null 消息不崩溃
    func testParseContextUsage_nilMessage() {
        monitor.clearAll()
        let session = Session(
            sessionId: "test-1",
            cwd: "/project",
            status: .coding,
            notificationMessage: nil
        )

        XCTAssertNoThrow(monitor.handleSessionUpdate(session))
    }

    // MARK: - Session contextUsage 字段同步测试

    /// 测试：从 session.contextUsage 字段同步快照
    func testHandleSessionUpdate_fromSessionContextUsage() {
        let session = Session(
            sessionId: "test-1",
            cwd: "/project",
            status: .coding,
            contextUsage: 0.65,
            contextTokensUsed: 130000,
            contextTokensTotal: 200000
        )

        monitor.handleSessionUpdate(session)

        let snapshot = monitor.snapshots["test-1"]
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.usageRatio ?? 0, 0.65, accuracy: 0.01)
        XCTAssertEqual(snapshot?.tokensUsed, 130000)
        XCTAssertEqual(snapshot?.tokensTotal, 200000)
    }

    // MARK: - topSnapshot 测试

    /// 测试：topSnapshot 返回使用率最高的会话
    func testTopSnapshot_highestUsage() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "s1", usage: 0.50)
        monitor.setContextUsage(sessionId: "s2", usage: 0.85)
        monitor.setContextUsage(sessionId: "s3", usage: 0.70)

        let top = monitor.topSnapshot
        XCTAssertNotNil(top)
        XCTAssertEqual(top?.sessionId, "s2")
        XCTAssertEqual(top?.usageRatio ?? 0, 0.85, accuracy: 0.01)
    }

    /// 测试：topSnapshot 忽略 usageRatio 为 0 的会话
    func testTopSnapshot_ignoresZero() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "s1", usage: 0.0)
        monitor.setContextUsage(sessionId: "s2", usage: 0.60)

        let top = monitor.topSnapshot
        XCTAssertNotNil(top)
        XCTAssertEqual(top?.sessionId, "s2")
    }

    // MARK: - 警告/危险阈值触发测试

    /// 测试：有会话超过警告阈值时 hasWarning 为 true
    func testHasWarning_withWarning() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "s1", usage: 0.85)
        XCTAssertTrue(monitor.hasWarning)
    }

    /// 测试：所有会话低于警告阈值时 hasWarning 为 false
    func testHasWarning_noWarning() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "s1", usage: 0.50)
        monitor.setContextUsage(sessionId: "s2", usage: 0.79)
        XCTAssertFalse(monitor.hasWarning)
    }

    /// 测试：有会话超过危险阈值时 hasCritical 为 true
    func testHasCritical_withCritical() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "s1", usage: 0.96)
        XCTAssertTrue(monitor.hasCritical)
    }

    /// 测试：所有会话低于危险阈值时 hasCritical 为 false
    func testHasCritical_noCritical() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "s1", usage: 0.90)
        XCTAssertFalse(monitor.hasCritical)
    }

    /// 测试：hasCritical 时 shouldFlashWarning 也为 true
    func testShouldFlashWarning_withCritical() {
        monitor.clearAll()
        monitor.setContextUsage(sessionId: "s1", usage: 0.96)
        XCTAssertTrue(monitor.shouldFlashWarning)
        XCTAssertTrue(monitor.hasCritical)
    }

    // MARK: - 清理测试

    /// 测试：清除单个会话快照
    func testClearSnapshot_single() {
        monitor.setContextUsage(sessionId: "s1", usage: 0.50)
        monitor.setContextUsage(sessionId: "s2", usage: 0.60)

        monitor.clearSnapshot(for: "s1")

        XCTAssertNil(monitor.snapshots["s1"])
        XCTAssertNotNil(monitor.snapshots["s2"])
    }

    /// 测试：清除所有快照
    func testClearAll() {
        monitor.setContextUsage(sessionId: "s1", usage: 0.50)
        monitor.setContextUsage(sessionId: "s2", usage: 0.60)

        monitor.clearAll()

        XCTAssertTrue(monitor.snapshots.isEmpty)
    }

    // MARK: - 生命周期测试

    /// 测试：start 方法不崩溃
    func testStart_noCrash() {
        XCTAssertNoThrow(monitor.start())
    }

    /// 测试：stop 方法清除所有快照
    func testStop_clearsSnapshots() {
        monitor.setContextUsage(sessionId: "s1", usage: 0.50)
        monitor.stop()
        XCTAssertTrue(monitor.snapshots.isEmpty)
    }
}
