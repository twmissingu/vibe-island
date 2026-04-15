import Foundation
import OSLog

// MARK: - 工具来源标识

/// 支持的 LLM 编码工具
enum ToolSource: String, Codable, Equatable, Sendable {
    case claudeCode = "claude_code"
    case openCode = "opencode"
    case codex = "codex"

    /// 显示名称
    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .openCode: return "OpenCode"
        case .codex: return "Codex"
        }
    }

    /// 工具图标标识
    var iconSymbol: String {
        switch self {
        case .claudeCode: return "C"
        case .openCode: return "O"
        case .codex: return "X"
        }
    }
}

// MARK: - 统一会话视图模型

/// 统一的会话视图模型，屏蔽不同工具的差异
struct UnifiedSessionView: Identifiable, Equatable, Sendable {
    /// 唯一标识
    let id: String
    /// 工具来源
    let source: ToolSource
    /// 原始会话 ID
    let originalSessionId: String
    /// 工作目录
    let cwd: String
    /// 当前状态
    var status: SessionState
    /// 会话名称
    var name: String?
    /// 最后工具
    var lastTool: String?
    /// 通知消息
    var message: String?
    /// 最后活动时间
    var lastActivity: Date
    /// 活跃子代理数量
    var activeSubagentCount: Int

    /// 是否需要闪烁警告
    var isBlinking: Bool {
        status.isBlinking
    }

    /// 简化的显示名称
    var shortName: String {
        name ?? "\(source.displayName): \(cwd.split(separator: "/").last?.description ?? cwd)"
    }
}

// MARK: - 多工具状态聚合器

/// 聚合 Claude Code、OpenCode、Codex 的状态
///
/// 职责：
/// - 从各监控服务收集会话状态
/// - 按优先级排序：审批 > 错误 > 运行 > 空闲
/// - 提供统一的查询接口
/// - @MainActor @Observable 支持 UI 更新
@MainActor
@Observable
final class MultiToolAggregator {

    // MARK: 常量

    /// 聚合刷新间隔（秒）
    static let refreshInterval: TimeInterval = 3.0

    // MARK: 单例

    static let shared = MultiToolAggregator()

    // MARK: 公开状态

    /// 所有工具的统一会话视图
    private(set) var unifiedSessions: [UnifiedSessionView] = []

    /// 按优先级排序的会话列表
    var sortedSessions: [UnifiedSessionView] {
        unifiedSessions.sorted { $0.status.priority < $1.status.priority }
    }

    /// 最高优先级状态（用于菜单栏/全局展示）
    var topStatus: SessionState {
        unifiedSessions
            .map(\.status)
            .min(by: { $0.priority < $1.priority })
            ?? .idle
    }

    /// 活跃会话总数
    var activeCount: Int {
        unifiedSessions.filter { $0.status != .idle && $0.status != .completed }.count
    }

    /// 各工具的活跃数量
    var countBySource: [ToolSource: Int] {
        var counts: [ToolSource: Int] = [:]
        for source in ToolSource.allCases {
            counts[source] = unifiedSessions.filter {
                $0.source == source && $0.status != .idle && $0.status != .completed
            }.count
        }
        return counts
    }

    /// 是否有等待权限审批的会话
    var hasPendingPermission: Bool {
        unifiedSessions.contains { $0.status == .waitingPermission }
    }

    /// 是否有错误会话
    var hasError: Bool {
        unifiedSessions.contains { $0.status == .error }
    }

    /// 聚合器是否已启动
    private(set) var isRunning = false

    // MARK: 内部依赖

    private let sessionManager = SessionManager.shared
    private let openCodeMonitor = OpenCodeMonitor.shared
    private let codexMonitor = CodexMonitor.shared
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "MultiToolAggregator"
    )

    // MARK: 内部状态

    private var hasSetup = false
    private var refreshTimer: Timer?

    // MARK: 初始化

    private init() {}

    // MARK: 生命周期

    /// 启动聚合器
    func start() {
        guard !hasSetup else { return }
        hasSetup = true
        isRunning = true

        // 启动各子监控服务
        sessionManager.start()
        openCodeMonitor.start()
        codexMonitor.start()

        // 设置定时聚合刷新
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: Self.refreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.aggregate()
            }
        }

        // 立即聚合一次
        aggregate()

        Self.logger.info("MultiToolAggregator 已启动")
    }

    /// 停止聚合器
    func stop() {
        hasSetup = false
        isRunning = false

        sessionManager.stop()
        openCodeMonitor.stop()
        codexMonitor.stop()

        refreshTimer?.invalidate()
        refreshTimer = nil

        unifiedSessions.removeAll()

        Self.logger.info("MultiToolAggregator 已停止")
    }

    /// 手动刷新所有会话
    func refresh() {
        sessionManager.refresh()
        openCodeMonitor.refresh()
        codexMonitor.refresh()
        aggregate()
    }

    // MARK: 聚合逻辑

    /// 聚合所有工具的会话状态
    private func aggregate() {
        var sessions: [UnifiedSessionView] = []

        // 1. 收集 Claude Code 会话（来自 SessionManager）
        let claudeSessions = sessionManager.sessions.values.map { session -> UnifiedSessionView in
            UnifiedSessionView(
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
            )
        }
        sessions.append(contentsOf: claudeSessions)

        // 2. 收集 OpenCode 会话
        let openCodeSessions = openCodeMonitor.sessions.map { session -> UnifiedSessionView in
            UnifiedSessionView(
                id: "opencode_\(session.sessionId)",
                source: .openCode,
                originalSessionId: session.sessionId,
                cwd: session.cwd,
                status: session.status.toSessionState,
                name: "OpenCode: \(session.cwd.split(separator: "/").last?.description ?? session.cwd)",
                lastTool: session.currentTool,
                message: session.message,
                lastActivity: session.lastActivity,
                activeSubagentCount: 0
            )
        }
        sessions.append(contentsOf: openCodeSessions)

        // 3. 收集 Codex 会话
        let codexSessions = codexMonitor.sessions.map { session -> UnifiedSessionView in
            UnifiedSessionView(
                id: "codex_\(session.sessionId)",
                source: .codex,
                originalSessionId: session.sessionId,
                cwd: session.cwd ?? "unknown",
                status: session.status.toSessionState,
                name: "Codex: \(session.cwd?.split(separator: "/").last?.description ?? "unknown")",
                lastTool: nil,
                message: nil,
                lastActivity: session.lastCheck,
                activeSubagentCount: 0
            )
        }
        sessions.append(contentsOf: codexSessions)

        unifiedSessions = sessions
    }

    // MARK: 查询方法

    /// 获取指定工具来源的会话
    func sessions(from source: ToolSource) -> [UnifiedSessionView] {
        unifiedSessions.filter { $0.source == source }
    }

    /// 获取指定目录下的所有会话
    func sessions(in cwd: String) -> [UnifiedSessionView] {
        unifiedSessions.filter { $0.cwd.contains(cwd) }
    }

    /// 获取指定状态的会话
    func sessions(with status: SessionState) -> [UnifiedSessionView] {
        unifiedSessions.filter { $0.status == status }
    }

    /// 获取最高优先级的会话
    func topSession() -> UnifiedSessionView? {
        sortedSessions.first
    }

    /// 获取指定 cwd 下的聚合状态
    func aggregateState(for cwd: String) -> SessionState {
        let cwdSessions = sessions(in: cwd)
        return cwdSessions
            .map(\.status)
            .min(by: { $0.priority < $1.priority })
            ?? .idle
    }

    /// 获取最近活跃的会话
    func recentSessions(limit: Int = 10) -> [UnifiedSessionView] {
        unifiedSessions
            .sorted { $0.lastActivity > $1.lastActivity }
            .prefix(limit)
            .map { $0 }
    }

    /// 按工具来源分组的摘要文本
    func summaryText() -> String {
        let claudeCount = countBySource[.claudeCode] ?? 0
        let openCodeCount = countBySource[.openCode] ?? 0
        let codexCount = countBySource[.codex] ?? 0
        let total = activeCount

        guard total > 0 else {
            return "\u{2713} 无活跃会话"
        }

        var parts: [String] = []
        if claudeCount > 0 {
            parts.append("Claude:\(claudeCount)")
        }
        if openCodeCount > 0 {
            parts.append("OpenCode:\(openCodeCount)")
        }
        if codexCount > 0 {
            parts.append("Codex:\(codexCount)")
        }

        let detail = parts.joined(separator: " | ")
        let prefix: String
        if hasError {
            prefix = "\u{26A0}\u{FE0F}"
        } else if hasPendingPermission {
            prefix = "\u{1F512}"
        } else {
            prefix = "\u{1F528}"
        }

        return "\(prefix) \(total) 活跃 (\(detail))"
    }

    /// 清除指定工具的已完成会话
    func cleanupCompletedSessions(for source: ToolSource?) {
        // 此操作由各子服务自行处理
        if let source {
            switch source {
            case .claudeCode:
                sessionManager.removeCompletedSessions()
            case .openCode:
                // OpenCodeMonitor 自动过滤 PID 不存活的会话
                break
            case .codex:
                // Codex 检测自动清理
                break
            }
        } else {
            sessionManager.removeCompletedSessions()
        }
    }

    /// 清除所有会话缓存
    func clearAll() {
        sessionManager.clearAll()
        openCodeMonitor.stop()
        openCodeMonitor.start()
        codexMonitor.stop()
        codexMonitor.start()
        aggregate()
    }
}

// MARK: - ToolSource 便捷扩展

extension ToolSource {
    static var allCases: [ToolSource] { [.claudeCode, .openCode, .codex] }
}
