import XCTest
import Foundation
@testable import VibeIsland

/// 上下文监控集成测试
/// 验证：ContextUsageSnapshot 计算正确性、阈值行为、边界情况
@MainActor
final class ContextMonitorIntegrationTests: XCTestCase {

    // MARK: - 辅助方法

    /// 创建测试用会话
    private func makeSession(
        id: String,
        status: SessionState = .idle,
        cwd: String = "/tmp/project",
        contextUsage: Double? = nil,
        contextTokensUsed: Int? = nil,
        contextTokensTotal: Int? = nil
    ) -> Session {
        Session(
            sessionId: id,
            cwd: cwd,
            status: status,
            lastActivity: Date(),
            contextUsage: contextUsage,
            contextTokensUsed: contextTokensUsed,
            contextTokensTotal: contextTokensTotal
        )
    }

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

    // MARK: - Session contextUsage 字段测试

    /// 测试：Session 的 contextUsage 字段可直接用于构建 ContextUsageSnapshot
    func testSessionContextUsageField_buildsSnapshot() {
        let session = makeSession(
            id: "sync-1",
            status: .coding,
            contextUsage: 0.72,
            contextTokensUsed: 144000,
            contextTokensTotal: 200000
        )

        guard let usage = session.contextUsage else {
            XCTFail("contextUsage 不应为 nil")
            return
        }

        let snapshot = ContextUsageSnapshot(
            sessionId: session.sessionId,
            usageRatio: usage,
            tokensUsed: session.contextTokensUsed,
            tokensTotal: session.contextTokensTotal,
            inputTokens: session.contextInputTokens,
            outputTokens: session.contextOutputTokens,
            reasoningTokens: session.contextReasoningTokens,
            timestamp: session.lastActivity
        )

        XCTAssertEqual(snapshot.usageRatio, 0.72, accuracy: 0.01)
        XCTAssertEqual(snapshot.tokensUsed, 144000)
        XCTAssertEqual(snapshot.tokensTotal, 200000)
    }

    // MARK: - 阈值警告触发测试

    /// 测试：使用率低于警告阈值时，不应警告
    func testBelowWarningThreshold_noWarning() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "safe-1", usageRatio: 0.50,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertFalse(snapshot.isWarning)
    }

    /// 测试：使用率等于警告阈值时，应警告
    func testAtWarningThreshold_warningTriggered() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "warn-1", usageRatio: 0.80,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(snapshot.isWarning)
    }

    /// 测试：使用率略高于警告阈值时，应警告
    func testAboveWarningThreshold_warningTriggered() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "warn-2", usageRatio: 0.85,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(snapshot.isWarning)
    }

    /// 测试：使用率低于危险阈值但高于警告阈值时，不应危险
    func testBelowCriticalThreshold_noCritical() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "warn-only", usageRatio: 0.90,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(snapshot.isWarning)
        XCTAssertFalse(snapshot.isCritical)
    }

    /// 测试：使用率等于危险阈值时，应危险
    func testAtCriticalThreshold_criticalTriggered() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "critical-1", usageRatio: 0.95,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(snapshot.isCritical)
        XCTAssertTrue(snapshot.isWarning) // 危险时警告也应为 true
    }

    /// 测试：使用率超过危险阈值时，应危险
    func testAboveCriticalThreshold_criticalTriggered() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "critical-2", usageRatio: 0.99,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(snapshot.isCritical)
        XCTAssertTrue(snapshot.isWarning)
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
        XCTAssertEqual(snapshot.usagePercent, 86) // Int((0.857 * 100).rounded()) = 86
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
        let snapshot = ContextUsageSnapshot(
            sessionId: "zero", usageRatio: 0.0,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertFalse(snapshot.isWarning)
        XCTAssertFalse(snapshot.isCritical)
    }

    /// 测试：使用率为 1.0（100%）时触发危险
    func testFullUsage_critical() {
        let snapshot = ContextUsageSnapshot(
            sessionId: "full", usageRatio: 1.0,
            tokensUsed: nil, tokensTotal: nil, timestamp: Date()
        )
        XCTAssertTrue(snapshot.isCritical)
        XCTAssertTrue(snapshot.isWarning)
    }

    /// 测试：nil contextUsage 的 Session 不构建无效快照
    func testNilContextUsage_noSnapshot() {
        let session = makeSession(id: "nil-usage", status: .coding)
        XCTAssertNil(session.contextUsage)
    }

    /// 测试：空 message 不崩溃
    func testEmptyMessage_noCrash() {
        let session = makeSession(
            id: "empty-msg",
            status: .compacting
        )
        // 仅验证构造不崩溃
        XCTAssertEqual(session.sessionId, "empty-msg")
    }

    // MARK: - 端到端数据流测试（基于 Session 模型）

    /// 测试：完整事件流 -> Session 模型 -> ContextUsageSnapshot
    func testEndToEnd_sessionToSnapshot() {
        // 第一步：会话开始，无上下文使用数据
        var session = makeSession(id: "e2e-1", status: .thinking)
        XCTAssertNil(session.contextUsage)

        // 第二步：开始编码，上下文使用率较低
        session = makeSession(
            id: "e2e-1",
            status: .coding,
            contextUsage: 0.40,
            contextTokensUsed: 80000,
            contextTokensTotal: 200000
        )

        let snapshot1 = ContextUsageSnapshot(
            sessionId: session.sessionId,
            usageRatio: session.contextUsage ?? 0,
            tokensUsed: session.contextTokensUsed,
            tokensTotal: session.contextTokensTotal,
            timestamp: session.lastActivity
        )
        XCTAssertEqual(snapshot1.usageRatio, 0.40, accuracy: 0.01)
        XCTAssertFalse(snapshot1.isWarning)

        // 第三步：使用率达到警告阈值
        session = makeSession(
            id: "e2e-1",
            status: .compacting,
            contextUsage: 0.82,
            contextTokensUsed: 164000,
            contextTokensTotal: 200000
        )

        let snapshot2 = ContextUsageSnapshot(
            sessionId: session.sessionId,
            usageRatio: session.contextUsage ?? 0,
            tokensUsed: session.contextTokensUsed,
            tokensTotal: session.contextTokensTotal,
            timestamp: session.lastActivity
        )
        XCTAssertEqual(snapshot2.usageRatio, 0.82, accuracy: 0.01)
        XCTAssertEqual(snapshot2.tokensUsed, 164000)
        XCTAssertTrue(snapshot2.isWarning)
        XCTAssertFalse(snapshot2.isCritical)
    }

    /// 测试：PreCompact 事件流 -> 使用率持续上升 -> 危险阈值触发
    func testEndToEnd_usageRisingToCritical() {
        // 第一阶段：60% 使用率
        var session = makeSession(
            id: "e2e-2",
            status: .coding,
            contextUsage: 0.60
        )
        let snapshot1 = ContextUsageSnapshot(
            sessionId: session.sessionId,
            usageRatio: session.contextUsage ?? 0,
            timestamp: session.lastActivity
        )
        XCTAssertFalse(snapshot1.isWarning)

        // 第二阶段：85% 使用率（警告）
        session = makeSession(
            id: "e2e-2",
            status: .compacting,
            contextUsage: 0.85,
            contextTokensUsed: 170000,
            contextTokensTotal: 200000
        )
        let snapshot2 = ContextUsageSnapshot(
            sessionId: session.sessionId,
            usageRatio: session.contextUsage ?? 0,
            tokensUsed: session.contextTokensUsed,
            tokensTotal: session.contextTokensTotal,
            timestamp: session.lastActivity
        )
        XCTAssertTrue(snapshot2.isWarning)
        XCTAssertFalse(snapshot2.isCritical)

        // 第三阶段：96% 使用率（危险）
        session = makeSession(
            id: "e2e-2",
            status: .compacting,
            contextUsage: 0.96,
            contextTokensUsed: 192000,
            contextTokensTotal: 200000
        )
        let snapshot3 = ContextUsageSnapshot(
            sessionId: session.sessionId,
            usageRatio: session.contextUsage ?? 0,
            tokensUsed: session.contextTokensUsed,
            tokensTotal: session.contextTokensTotal,
            timestamp: session.lastActivity
        )
        XCTAssertTrue(snapshot3.isWarning)
        XCTAssertTrue(snapshot3.isCritical)

        // 验证快照数据
        XCTAssertEqual(snapshot3.usageRatio, 0.96, accuracy: 0.01)
        XCTAssertEqual(snapshot3.tokensRemaining, 8000) // 200000 - 192000
    }
}
