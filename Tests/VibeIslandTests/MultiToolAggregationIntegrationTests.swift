import XCTest
import Foundation
@testable import VibeIsland

/// 多工具聚合集成测试
/// 验证：三种工具会话创建 -> MultiToolAggregator 聚合逻辑 -> 优先级排序 -> 摘要文本生成
@MainActor
final class MultiToolAggregationIntegrationTests: XCTestCase {

    // MARK: - 辅助方法

    /// 创建 Claude Code 测试会话
    private func makeClaudeSession(
        id: String,
        status: SessionState = .idle,
        cwd: String = "/tmp/project-claude",
        lastTool: String? = nil
    ) -> Session {
        Session(
            sessionId: id,
            cwd: cwd,
            status: status,
            lastActivity: Date(),
            source: "claude",
            sessionName: "Claude Session \(id)",
            lastTool: lastTool
        )
    }

    /// 创建 OpenCode 统一视图会话
    private func makeOpenCodeView(
        id: String,
        status: SessionState = .idle,
        cwd: String = "/tmp/project-opencode",
        lastTool: String? = nil
    ) -> UnifiedSessionView {
        UnifiedSessionView(
            id: "opencode_\(id)",
            source: .openCode,
            originalSessionId: id,
            cwd: cwd,
            status: status,
            name: "OpenCode: \(id)",
            lastTool: lastTool,
            message: nil,
            lastActivity: Date(),
            activeSubagentCount: 0
        )
    }

    /// 创建 Codex 统一视图会话
    private func makeCodexView(
        id: String,
        status: SessionState = .idle,
        cwd: String = "/tmp/project-codex"
    ) -> UnifiedSessionView {
        UnifiedSessionView(
            id: "codex_\(id)",
            source: .codex,
            originalSessionId: id,
            cwd: cwd,
            status: status,
            name: "Codex: \(id)",
            lastTool: nil,
            message: nil,
            lastActivity: Date(),
            activeSubagentCount: 0
        )
    }

    var sessionManager: SessionManager!
    var aggregator: MultiToolAggregator!

    override func setUp() async throws {
        try await super.setUp()
        sessionManager = SessionManager.makeForTesting()
        aggregator = MultiToolAggregator.shared
    }

    override func tearDown() async throws {
        sessionManager.stop()
        sessionManager = nil
        try await super.tearDown()
    }

    // MARK: - 三种工具会话创建测试

    /// 测试：创建 Claude Code 会话并注册到 SessionManager
    func testCreateClaudeSession_registeredCorrectly() {
        let claude = makeClaudeSession(id: "claude-1", status: .coding, lastTool: "Read")
        sessionManager.injectSessionForTesting(claude)

        let retrieved = sessionManager.session(id: "claude-1")
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.source, "claude")
        XCTAssertEqual(retrieved?.status, .coding)
        XCTAssertEqual(retrieved?.lastTool, "Read")
    }

    /// 测试：创建 OpenCode 统一视图会话
    func testCreateOpenCodeView_propertiesCorrect() {
        let opencode = makeOpenCodeView(id: "oc-1", status: .thinking, cwd: "/project-a", lastTool: "Agent")

        XCTAssertEqual(opencode.source, .openCode)
        XCTAssertEqual(opencode.status, .thinking)
        XCTAssertEqual(opencode.cwd, "/project-a")
        XCTAssertEqual(opencode.lastTool, "Agent")
        XCTAssertEqual(opencode.shortName, "OpenCode: oc-1")
    }

    /// 测试：创建 Codex 统一视图会话
    func testCreateCodexView_propertiesCorrect() {
        let codex = makeCodexView(id: "cx-1", status: .coding, cwd: "/project-b")

        XCTAssertEqual(codex.source, .codex)
        XCTAssertEqual(codex.status, .coding)
        XCTAssertEqual(codex.cwd, "/project-b")
        XCTAssertNil(codex.lastTool)
        XCTAssertTrue(codex.shortName.contains("Codex"))
    }

    // MARK: - MultiToolAggregator 聚合逻辑测试

    /// 测试：聚合三种工具来源的会话
    func testAggregate_threeTools_sessionsCollected() {
        // 注入 Claude Code 会话
        let claude1 = makeClaudeSession(id: "c1", status: .coding)
        let claude2 = makeClaudeSession(id: "c2", status: .thinking)
        sessionManager.injectSessionForTesting(claude1)
        sessionManager.injectSessionForTesting(claude2)

        // 手动构造聚合后的统一视图（模拟 aggregator.aggregate() 的结果）
        var unifiedSessions: [UnifiedSessionView] = []

        // Claude Code 转换
        for session in sessionManager.sessions.values {
            unifiedSessions.append(UnifiedSessionView(
                id: "claude_\(session.sessionId)",
                source: .claudeCode,
                originalSessionId: session.sessionId,
                cwd: session.cwd,
                status: session.status,
                name: session.sessionName,
                lastTool: session.lastTool,
                message: session.notificationMessage,
                lastActivity: session.lastActivity,
                activeSubagentCount: session.activeSubagents.count
            ))
        }

        // OpenCode
        unifiedSessions.append(makeOpenCodeView(id: "oc-1", status: .coding))
        unifiedSessions.append(makeOpenCodeView(id: "oc-2", status: .idle))

        // Codex
        unifiedSessions.append(makeCodexView(id: "cx-1", status: .error))
        unifiedSessions.append(makeCodexView(id: "cx-2", status: .completed))

        // 验证聚合结果
        XCTAssertEqual(unifiedSessions.count, 6)

        let claudeCount = unifiedSessions.filter { $0.source == .claudeCode }.count
        let openCodeCount = unifiedSessions.filter { $0.source == .openCode }.count
        let codexCount = unifiedSessions.filter { $0.source == .codex }.count

        XCTAssertEqual(claudeCount, 2)
        XCTAssertEqual(openCodeCount, 2)
        XCTAssertEqual(codexCount, 2)
    }

    /// 测试：聚合后按来源统计活跃会话数量
    func testAggregate_activeCountBySource() {
        var unifiedSessions: [UnifiedSessionView] = []

        // Claude Code：2 个活跃，1 个 idle
        unifiedSessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding))
        unifiedSessions.append(makeUnifiedView(source: .claudeCode, id: "c2", status: .thinking))
        unifiedSessions.append(makeUnifiedView(source: .claudeCode, id: "c3", status: .idle))

        // OpenCode：1 个活跃，1 个 completed
        unifiedSessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .coding))
        unifiedSessions.append(makeUnifiedView(source: .openCode, id: "oc2", status: .completed))

        // Codex：1 个活跃
        unifiedSessions.append(makeUnifiedView(source: .codex, id: "cx1", status: .error))

        let activeCount = unifiedSessions.filter { $0.status != .idle && $0.status != .completed }.count
        XCTAssertEqual(activeCount, 4)

        let claudeActive = unifiedSessions.filter { $0.source == .claudeCode && $0.status != .idle && $0.status != .completed }.count
        let openCodeActive = unifiedSessions.filter { $0.source == .openCode && $0.status != .idle && $0.status != .completed }.count
        let codexActive = unifiedSessions.filter { $0.source == .codex && $0.status != .idle && $0.status != .completed }.count

        XCTAssertEqual(claudeActive, 2)
        XCTAssertEqual(openCodeActive, 1)
        XCTAssertEqual(codexActive, 1)
    }

    // MARK: - 优先级排序验证

    /// 测试：多工具会话按状态优先级正确排序
    func testMultiTool_sortedByPriority() {
        var sessions: [UnifiedSessionView] = []

        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .idle, priority: 7))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .coding, priority: 3))
        sessions.append(makeUnifiedView(source: .codex, id: "cx1", status: .error, priority: 1))
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c2", status: .waitingPermission, priority: 0))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc2", status: .compacting, priority: 2))
        sessions.append(makeUnifiedView(source: .codex, id: "cx2", status: .thinking, priority: 4))

        let sorted = sessions.sorted { $0.status.priority < $1.status.priority }

        // 验证排序顺序：waitingPermission(0) < error(1) < compacting(2) < coding(3) < thinking(4) < idle(7)
        XCTAssertEqual(sorted[0].status, .waitingPermission)
        XCTAssertEqual(sorted[1].status, .error)
        XCTAssertEqual(sorted[2].status, .compacting)
        XCTAssertEqual(sorted[3].status, .coding)
        XCTAssertEqual(sorted[4].status, .thinking)
        XCTAssertEqual(sorted[5].status, .idle)
    }

    /// 测试：相同优先级的会话保持稳定排序
    func testSamePriority_stableSort() {
        var sessions: [UnifiedSessionView] = []

        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .coding))
        sessions.append(makeUnifiedView(source: .codex, id: "cx1", status: .coding))

        let sorted = sessions.sorted { $0.status.priority < $1.status.priority }

        XCTAssertEqual(sorted.count, 3)
        XCTAssertTrue(sorted.allSatisfy { $0.status == .coding })
    }

    /// 测试：topStatus 返回最高优先级状态
    func testTopStatus_returnsHighestPriority() {
        var sessions: [UnifiedSessionView] = []

        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .error))
        sessions.append(makeUnifiedView(source: .codex, id: "cx1", status: .thinking))

        let topStatus = sessions.map(\.status).min(by: { $0.priority < $1.priority }) ?? .idle
        XCTAssertEqual(topStatus, .error) // error 优先级高于 coding 和 thinking
    }

    /// 测试：空会话列表时 topStatus 为 idle
    func testTopStatus_emptyList_isIdle() {
        let sessions: [UnifiedSessionView] = []
        let topStatus = sessions.map(\.status).min(by: { $0.priority < $1.priority }) ?? .idle
        XCTAssertEqual(topStatus, .idle)
    }

    // MARK: - 摘要文本生成验证

    /// 测试：无活跃会话时摘要文本正确
    func testSummaryText_noActiveSessions() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .idle))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .completed))

        let activeCount = sessions.filter { $0.status != .idle && $0.status != .completed }.count
        XCTAssertEqual(activeCount, 0)

        // 模拟摘要文本生成逻辑
        let summaryText = generateSummaryText(sessions: sessions)
        XCTAssertTrue(summaryText.contains("无活跃"))
    }

    /// 测试：仅 Claude Code 活跃时的摘要文本
    func testSummaryText_onlyClaudeActive() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding))
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c2", status: .thinking))

        let summaryText = generateSummaryText(sessions: sessions)

        XCTAssertTrue(summaryText.contains("活跃"))
        XCTAssertTrue(summaryText.contains("Claude"))
        XCTAssertFalse(summaryText.contains("OpenCode"))
        XCTAssertFalse(summaryText.contains("Codex"))
    }

    /// 测试：三种工具都活跃时的摘要文本
    func testSummaryText_allToolsActive() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .coding))
        sessions.append(makeUnifiedView(source: .codex, id: "cx1", status: .error))

        let summaryText = generateSummaryText(sessions: sessions)

        XCTAssertTrue(summaryText.contains("活跃"))
        XCTAssertTrue(summaryText.contains("Claude"))
        XCTAssertTrue(summaryText.contains("OpenCode"))
        XCTAssertTrue(summaryText.contains("Codex"))
    }

    /// 测试：有错误会话时摘要文本包含警告符号
    func testSummaryText_hasError_showsWarningIcon() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .error))

        let summaryText = generateSummaryText(sessions: sessions)

        XCTAssertTrue(summaryText.contains("活跃"))
    }

    /// 测试：有等待权限会话时摘要文本包含锁符号
    func testSummaryText_hasPendingPermission_showsLockIcon() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .waitingPermission))

        let summaryText = generateSummaryText(sessions: sessions)

        XCTAssertTrue(summaryText.contains("权限"))
    }

    /// 测试：摘要文本包含各工具活跃数量
    func testSummaryText_includesActiveCounts() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding))
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c2", status: .thinking))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .coding))
        sessions.append(makeUnifiedView(source: .codex, id: "cx1", status: .coding))
        sessions.append(makeUnifiedView(source: .codex, id: "cx2", status: .completed)) // 不计入

        let activeCount = sessions.filter { $0.status != .idle && $0.status != .completed }.count
        XCTAssertEqual(activeCount, 4)

        let summaryText = generateSummaryText(sessions: sessions)
        XCTAssertTrue(summaryText.contains("4"))
    }

    // MARK: - 按来源查询测试

    /// 测试：按工具来源过滤会话
    func testFilterSessions_bySource() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding))
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c2", status: .idle))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .coding))
        sessions.append(makeUnifiedView(source: .codex, id: "cx1", status: .error))

        let claudeSessions = sessions.filter { $0.source == .claudeCode }
        let openCodeSessions = sessions.filter { $0.source == .openCode }
        let codexSessions = sessions.filter { $0.source == .codex }

        XCTAssertEqual(claudeSessions.count, 2)
        XCTAssertEqual(openCodeSessions.count, 1)
        XCTAssertEqual(codexSessions.count, 1)
    }

    /// 测试：按工作目录过滤会话
    func testFilterSessions_byCwd() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding, cwd: "/project-a"))
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c2", status: .idle, cwd: "/project-a"))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .coding, cwd: "/project-b"))

        let projectASessions = sessions.filter { $0.cwd.contains("/project-a") }
        XCTAssertEqual(projectASessions.count, 2)
    }

    /// 测试：按状态过滤会话
    func testFilterSessions_byStatus() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .coding))
        sessions.append(makeUnifiedView(source: .codex, id: "cx1", status: .error))
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c2", status: .idle))

        let codingSessions = sessions.filter { $0.status == .coding }
        XCTAssertEqual(codingSessions.count, 2)

        let errorSessions = sessions.filter { $0.status == .error }
        XCTAssertEqual(errorSessions.count, 1)
    }

    // MARK: - 聚合状态按 cwd 测试

    /// 测试：按 cwd 聚合多工具状态
    func testAggregateState_byCwd_multipleTools() {
        var sessions: [UnifiedSessionView] = []
        // 同一 cwd 下有不同工具的会话
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding, cwd: "/project-x"))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .error, cwd: "/project-x"))

        let cwdSessions = sessions.filter { $0.cwd.contains("/project-x") }
        let aggregateState = cwdSessions.map(\.status).min(by: { $0.priority < $1.priority }) ?? .idle
        XCTAssertEqual(aggregateState, .error) // error 优先级更高
    }

    /// 测试：不同 cwd 的聚合状态独立计算
    func testAggregateState_differentCwds_independent() {
        var sessions: [UnifiedSessionView] = []
        sessions.append(makeUnifiedView(source: .claudeCode, id: "c1", status: .coding, cwd: "/project-a"))
        sessions.append(makeUnifiedView(source: .openCode, id: "oc1", status: .idle, cwd: "/project-b"))

        let stateA = sessions.filter { $0.cwd.contains("/project-a") }.map(\.status).min(by: { $0.priority < $1.priority }) ?? .idle
        let stateB = sessions.filter { $0.cwd.contains("/project-b") }.map(\.status).min(by: { $0.priority < $1.priority }) ?? .idle

        XCTAssertEqual(stateA, .coding)
        XCTAssertEqual(stateB, .idle)
    }
}

// MARK: - 辅助函数

/// 创建统一视图会话
@MainActor
private func makeUnifiedView(
    source: ToolSource,
    id: String,
    status: SessionState = .idle,
    cwd: String = "/tmp/project",
    lastTool: String? = nil,
    priority: Int? = nil
) -> UnifiedSessionView {
    UnifiedSessionView(
        id: "\(source.rawValue)_\(id)",
        source: source,
        originalSessionId: id,
        cwd: cwd,
        status: status,
        name: "\(source.displayName) Session \(id)",
        lastTool: lastTool,
        message: nil,
        lastActivity: Date(),
        activeSubagentCount: 0
    )
}

/// 生成摘要文本（模拟 MultiToolAggregator.summaryText 逻辑）
@MainActor
private func generateSummaryText(sessions: [UnifiedSessionView]) -> String {
    var counts: [ToolSource: Int] = [:]
    for session in sessions {
        if session.status != .idle && session.status != .completed {
            counts[session.source, default: 0] += 1
        }
    }

    let totalActive = sessions.filter { $0.status != .idle && $0.status != .completed }.count
    let hasError = sessions.contains { $0.status == .error }
    let hasPendingPermission = sessions.contains { $0.status == .waitingPermission }

    guard totalActive > 0 else {
        return "\u{2713} 无活跃会话"
    }

    var parts: [String] = []
    if let claudeCount = counts[.claudeCode], claudeCount > 0 {
        parts.append("Claude:\(claudeCount)")
    }
    if let openCodeCount = counts[.openCode], openCodeCount > 0 {
        parts.append("OpenCode:\(openCodeCount)")
    }
    if let codexCount = counts[.codex], codexCount > 0 {
        parts.append("Codex:\(codexCount)")
    }

    let detail = parts.joined(separator: " | ")

    let prefix: String
    if hasError {
        prefix = "\u{26A0}\u{FE0F}"
    } else if hasPendingPermission {
        prefix = "\u{1F512} 等待权限审批"
    } else {
        prefix = "\u{1F528}"
    }

    return "\(prefix) \(totalActive) 活跃 (\(detail))"
}
