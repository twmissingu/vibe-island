import Foundation
import OSLog
import LLMQuotaKit

// MARK: - 跟踪模式

/// 灵动岛会话跟踪模式
enum TrackingMode: Equatable {
    /// 自动模式：始终显示最高优先级会话
    case auto
    /// 手动模式：固定跟踪指定会话
    case manual(sessionId: String)

    var isAuto: Bool {
        if case .auto = self { return true }
        return false
    }
}

// MARK: - 会话管理器（单例）

/// 管理多个会话的状态，提供状态聚合、优先级排序和查询功能
///
/// 多工具支持：
/// - Claude Code：通过文件 hook（SessionFileWatcher）
/// - OpenCode：通过 OpenCodeMonitor（四级降级）
///
/// SessionManager 主要管理 Claude Code 会话，
/// 多工具聚合由 MultiToolAggregator 负责。
@MainActor
@Observable
final class SessionManager: SessionAggregatable {
    // MARK: SessionAggregatable 实现
    var allSessions: [Session] { Array(sessions.values) }
    func sessionStatus(_ session: Session) -> SessionState { session.status }
    // MARK: 单例

    static let shared = SessionManager()

    // MARK: 公开状态

    /// 当前跟踪模式
    private(set) var trackingMode: TrackingMode = .auto
    /// 手动模式下固定的会话 ID
    var pinnedSessionId: String? {
        if case .manual(let id) = trackingMode { return id }
        return nil
    }
    /// 当前跟踪的会话（自动模式下为 sortedSessions 第一个，手动模式下为固定的会话）
    var trackedSession: Session? {
        switch trackingMode {
        case .auto:
            return sortedSessions.first
        case .manual(let sessionId):
            return sessions[sessionId]
        }
    }
    /// 当前跟踪的会话状态（用于紧凑岛显示）
    var trackedSessionState: SessionState {
        trackedSession?.status ?? .idle
    }
    /// 所有活跃会话（按 sessionId 索引）
    private(set) var sessions: [String: Session] = [:]
    /// 按最近活跃时间排序的会话列表
    var sortedSessions: [Session] {
        sessions.values.sorted { $0.lastActivity > $1.lastActivity }
    }

    // MARK: 内部依赖

    private let fileWatcher: SessionFileWatcher
    private let contextMonitor: ContextMonitor
    private var hasSetup = false
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "SessionManager"
    )

    // MARK: 初始化

    private init() {
        fileWatcher = SessionFileWatcher()
        contextMonitor = ContextMonitor.shared
    }

    // MARK: 测试专用方法

    /// 创建测试用的 SessionManager 实例（绕过单例和私有初始化）
    static func makeForTesting() -> SessionManager {
        let manager = SessionManager()
        return manager
    }

    /// 测试专用：设置跟踪模式
    func setTrackingModeForTesting(_ mode: TrackingMode) {
        trackingMode = mode
    }

    /// 测试专用：注入会话到 sessions 字典
    func injectSessionForTesting(_ session: Session) {
        sessions[session.sessionId] = session
    }

    /// 测试专用：移除会话
    func removeSessionForTesting(_ sessionId: String) {
        sessions.removeValue(forKey: sessionId)
    }

    /// 测试专用：清除所有会话（不触发 contextMonitor）
    func clearSessionsForTesting() {
        sessions.removeAll()
    }

    // MARK: 生命周期

    /// 启动管理器（必须在 MainActor 调用）
    func start() {
        guard !hasSetup else { return }
        hasSetup = true

        // 设置文件监听回调
        fileWatcher.onSessionUpdated { [weak self] sessionId, session in
            Task { @MainActor in
                self?.updateSession(sessionId, session)
            }
        }

        fileWatcher.startWatching()

        // 启动上下文监控
        contextMonitor.start()
        
        // 启动编码时长追踪
        CodingTimeTracker.shared.start()
        CodingTimeTracker.shared.tick()
        startCodingTimeTicker()

        Self.logger.info("SessionManager 已启动")
    }

    /// 停止管理器
    func stop() {
        hasSetup = false
        codingTimeTicker?.cancel()
        codingTimeTicker = nil
        fileWatcher.stopWatching()
        contextMonitor.stop()
        CodingTimeTracker.shared.stop()
        sessions.removeAll()
        Self.logger.info("SessionManager 已停止")
    }
    
    /// 编码时长定时更新（每 30 秒）
    @ObservationIgnored private var codingTimeTicker: Task<Void, Never>?

    private func startCodingTimeTicker() {
        codingTimeTicker?.cancel()
        codingTimeTicker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    CodingTimeTracker.shared.tick()
                    let totalMinutes = CodingTimeTracker.shared.totalCodingMinutes
                    PetProgressManager.shared.addCodingMinutes(totalMinutes)
                }
            }
        }
    }

    /// 手动刷新所有会话
    func refresh() {
        fileWatcher.refreshAll()
    }

    // MARK: 会话更新

    /// 更新单个会话状态
    private func updateSession(_ sessionId: String, _ session: Session) {
        sessions[sessionId] = session

        // 同步到上下文监控
        contextMonitor.handleSessionUpdate(session)
        
        // 同步到编码时长追踪器
        CodingTimeTracker.shared.handleSessionStateChange(sessionId: sessionId, state: session.status)
        
        // 同步到宠物进度管理器
        Task { @MainActor in
            PetProgressManager.shared.addCodingMinutes(CodingTimeTracker.shared.todayCodingMinutes)
        }
    }

    /// 注册外部工具的会话（OpenCode 等）
    /// - Parameter session: 外部工具会话
    func registerExternalSession(_ session: Session) {
        // 为外部会话生成唯一 ID，避免与 Claude Code 冲突
        let prefixedId = "\(session.source ?? "external")_\(session.sessionId)"
        sessions[prefixedId] = session

        Self.logger.debug("注册外部会话: \(prefixedId) (source: \(session.source ?? "unknown"))")
    }

    /// 移除外部工具的会话
    /// - Parameter sessionId: 会话 ID（可以是带前缀的 ID）
    func removeExternalSession(_ sessionId: String) {
        sessions.removeValue(forKey: sessionId)
    }

    // MARK: 查询方法

    /// 获取指定会话
    func session(id: String) -> Session? {
        sessions[id]
    }

    /// 获取指定目录下的所有会话
    func sessions(in cwd: String) -> [Session] {
        sessions.values.filter { $0.cwd == cwd }
    }

    /// 获取指定状态的会话
    func sessions(with status: SessionState) -> [Session] {
        sessions.values.filter { $0.status == status }
    }

    /// 获取包含特定工具调用的会话
    func sessions(using toolName: String) -> [Session] {
        sessions.values.filter { $0.lastTool == toolName }
    }

    /// 获取有活跃子代理的会话
    func sessionsWithSubagents() -> [Session] {
        sessions.values.filter { !$0.activeSubagents.isEmpty }
    }

    /// 获取最近的会话（按 lastActivity 排序）
    func recentSessions(limit: Int = 10) -> [Session] {
        sessions.values
            .sorted { $0.lastActivity > $1.lastActivity }
            .prefix(limit)
            .map { $0 }
    }

    /// 获取指定来源的会话
    func sessions(from source: String) -> [Session] {
        sessions.values.filter { $0.source == source }
    }

    /// 移除已完成的会话
    func removeCompletedSessions() {
        sessions = sessions.filter {
            $0.value.status != .completed
        }
    }

    /// 清除所有会话
    func clearAll() {
        sessions.removeAll()
        contextMonitor.clearAll()
    }

    // MARK: 状态聚合

    /// 计算给定 cwd 下的聚合状态
    func aggregateState(for cwd: String) -> SessionState {
        let cwdSessions = sessions(in: cwd)
        return cwdSessions
            .map(\.status)
            .min(by: { $0.priority < $1.priority })
            ?? .idle
    }

    /// 计算摘要文本（用于 UI 展示）
    func summaryText() -> String {
        let active = activeCount
        let pending = hasPendingPermission
        let errors = hasError

        if errors {
            return "\u{26A0}\u{FE0F} \(active) 个活跃会话"
        } else if pending {
            return "\u{1F512} 等待权限审批"
        } else if active > 0 {
            return "\u{1F528} \(active) 个活跃会话"
        } else {
            return "\u{2713} 无活跃会话"
        }
    }

    // MARK: 多工具集成

    /// 获取所有工具来源的汇总摘要
    /// 用于 UI 展示多工具统一状态
    func multiToolSummary() -> String {
        var parts: [String] = []

        // Claude Code
        let claudeActive = sessions.values.filter {
            ($0.source == nil || $0.source == "claude")
                && $0.status != .completed && $0.status != .idle
        }.count
        if claudeActive > 0 {
            parts.append("Claude:\(claudeActive)")
        }

        // OpenCode
        let openCodeActive = sessions.values.filter {
            $0.source == "opencode"
                && $0.status != .completed && $0.status != .idle
        }.count
        if openCodeActive > 0 {
            parts.append("OpenCode:\(openCodeActive)")
        }

        let total = claudeActive + openCodeActive

        guard total > 0 else {
            return "\u{2713} 无活跃会话"
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

    // MARK: 跟踪模式切换

    /// 切换到自动跟踪模式
    func setTrackingModeAuto() {
        trackingMode = .auto
        // 持久化到设置
        viewModel?.settings.sessionTrackingMode = "auto"
        viewModel?.settings.pinnedSessionId = nil
        saveSettings()
        Self.logger.info("切换到自动跟踪模式")
    }

    /// 切换到手动跟踪模式，固定指定会话
    /// - Parameter sessionId: 要固定的会话 ID
    func setTrackingModeManual(sessionId: String) {
        trackingMode = .manual(sessionId: sessionId)
        // 持久化到设置
        viewModel?.settings.sessionTrackingMode = "manual"
        viewModel?.settings.pinnedSessionId = sessionId
        saveSettings()
        Self.logger.info("切换到手动跟踪模式: \(sessionId)")
    }

    /// 切换自动/手动模式（用于快捷切换按钮）
    func toggleTrackingMode() {
        switch trackingMode {
        case .auto:
            // 如果有活跃会话，切换到第一个活跃会话的手动模式
            if let session = trackedSession {
                setTrackingModeManual(sessionId: session.sessionId)
            }
        case .manual:
            setTrackingModeAuto()
        }
    }

    /// 从设置中恢复跟踪模式
    func restoreTrackingMode() {
        let mode = viewModel?.settings.sessionTrackingMode ?? "auto"
        if mode == "manual", let pinnedId = viewModel?.settings.pinnedSessionId {
            trackingMode = .manual(sessionId: pinnedId)
        } else {
            trackingMode = .auto
        }
    }

    // MARK: - StateManager 引用（用于持久化设置）

    /// StateManager 引用，用于访问和保存设置
    /// 应在 StateManager.startMonitoring() 时设置
    weak var viewModel: StateManager? {
        didSet {
            restoreTrackingMode()
        }
    }

    private func saveSettings() {
        if let vm = viewModel {
            SharedDefaults.saveSettings(vm.settings)
        }
    }
}
