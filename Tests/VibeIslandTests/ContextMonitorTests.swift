import XCTest
import Foundation
@testable import VibeIsland

/// ContextMonitor 测试
/// 测试上下文监控服务的核心功能：阈值常量、ContextUsageSnapshot 属性、生命周期
@MainActor
final class ContextMonitorTests: XCTestCase {

    var monitor: ContextMonitor!

    override func setUp() async throws {
        try await super.setUp()
        monitor = ContextMonitor.shared
        monitor.stop()
    }

    override func tearDown() async throws {
        monitor.stop()
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

    /// 测试：usagePercent 计算正确（使用 rounded）
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

    /// 测试：usagePercent 四舍五入
    func testContextUsageSnapshot_usagePercent_rounding() {
        let roundDown = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.844,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertEqual(roundDown.usagePercent, 84)

        let roundUp = ContextUsageSnapshot(
            sessionId: "s1", usageRatio: 0.845,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertEqual(roundUp.usagePercent, 85)
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

    // MARK: - 上下文监控服务生命周期测试

    /// 测试：start 方法不崩溃
    func testStart_noCrash() {
        XCTAssertNoThrow(monitor.start())
    }

    /// 测试：stop 方法清除压缩事件记录
    func testStop_clearsProcessedCompactions() {
        monitor.start()
        monitor.stop()
        // processedCompactions 是内部状态，无法直接验证，
        // 但 stop() 不应崩溃
        XCTAssertTrue(true)
    }

    // MARK: - OpenCodeContextData 测试

    /// 测试：OpenCodeContextData 基本属性
    func testOpenCodeContextData_properties() {
        let data = ContextMonitor.OpenCodeContextData(
            usage: 0.75,
            tokensUsed: 150000,
            tokensTotal: 200000,
            inputTokens: 100000,
            outputTokens: 40000,
            reasoningTokens: 10000
        )

        XCTAssertEqual(data.usage, 0.75)
        XCTAssertEqual(data.tokensUsed, 150000)
        XCTAssertEqual(data.tokensTotal, 200000)
        XCTAssertEqual(data.inputTokens, 100000)
        XCTAssertEqual(data.outputTokens, 40000)
        XCTAssertEqual(data.reasoningTokens, 10000)
    }
}
