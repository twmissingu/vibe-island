import Foundation
import OSLog

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
/// SessionManager 统一管理所有工具会话（Claude Code + OpenCode）。
/// OpenCode 会话通过 registerExternalSession 注册。
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
    /// 按最近活跃时间排序的会话列表（缓存，mutation 时失效）
    private(set) var sortedSessions: [Session] = []
    /// aggregateState 变化回调（由 StateManager 设置，用于播放提示音）
    var onAggregateStateChanged: ((SessionState, SessionState) -> Void)?

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
        recomputeSortedSessions()
    }

    /// 测试专用：移除会话
    func removeSessionForTesting(_ sessionId: String) {
        sessions.removeValue(forKey: sessionId)
        recomputeSortedSessions()
    }

    /// 测试专用：清除所有会话（不触发 contextMonitor）
    func clearSessionsForTesting() {
        sessions.removeAll()
        sortedSessions = []
    }

    // MARK: 生命周期

    /// 启动管理器（必须在 MainActor 调用）
    func start() {
        guard !hasSetup else { return }
        hasSetup = true

        // 设置文件监听回调
        fileWatcher.onSessionUpdated { [weak self] sessionId, session in
            Task { @MainActor in
                await self?.updateSession(sessionId, session)

                // 检查 OpenCode 压缩状态（通过数据库）
                if session.source == "opencode" {
                    await self?.contextMonitor.checkOpenCodeCompaction(sessionId: sessionId, cwd: session.cwd)
                }
            }
        }

        fileWatcher.startWatching()

        // 启动上下文监控（OpenCode SQLite 读取）
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
        sortedSessions = []
        Self.logger.info("SessionManager 已停止")
    }
    
    /// 编码时长定时更新（每 30 秒）
    @ObservationIgnored private var codingTimeTicker: Task<Void, Never>?

    /// OpenCode DB 查询冷却：记录每个 cwd 上次查询时间，避免频繁 fork sqlite3 进程
    @ObservationIgnored private var lastOpenCodeQueryTime: [String: Date] = [:]
    private static let openCodeQueryCooldown: TimeInterval = 5.0

    /// 上次同步到 PetProgressManager 的累计总编码分钟数（定时器用，updateSession 不再重复同步）
    @ObservationIgnored private var lastSyncedTotalMinutes: Int = 0

    private func startCodingTimeTicker() {
        codingTimeTicker?.cancel()
        codingTimeTicker = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    CodingTimeTracker.shared.tick()
                    let totalMinutes = CodingTimeTracker.shared.totalCodingMinutes
                    let delta = totalMinutes - lastSyncedTotalMinutes
                    if delta > 0 {
                        PetProgressManager.shared.addCodingMinutes(delta)
                        lastSyncedTotalMinutes = totalMinutes
                    }
                }
            }
        }
    }
    
    /// 手动刷新所有会话
    func refresh() {
        fileWatcher.refreshAll()
    }

    // MARK: 会话更新

    /// 带冷却的 OpenCode DB 查询：避免每次文件变化都 fork sqlite3 进程
    private func fetchOpenCodeContextIfNeeded(cwd: String) async -> ContextMonitor.OpenCodeContextData? {
        let now = Date()
        if let lastTime = lastOpenCodeQueryTime[cwd],
           now.timeIntervalSince(lastTime) < Self.openCodeQueryCooldown {
            return nil
        }
        lastOpenCodeQueryTime[cwd] = now
        return await contextMonitor.fetchContextUsageFromOpenCodeDB(cwd: cwd)
    }

    /// 处理 OpenCode 压缩完成事件
    func handleOpenCodeCompaction(sessionId: String, compactionTime: Int64) {
        guard let session = sessions[sessionId] else { return }

        // 如果会话之前不是压缩状态，切换到压缩状态
        if session.status != .compacting {
            Self.logger.info("检测到 OpenCode 压缩: \(sessionId)")

            var updated = session
            updated.status = .compacting

            // 写回 session 文件
            try? updated.writeToFile()

            sessions[sessionId] = updated
            recomputeSortedSessions()

            let oldState = aggregateState
            onAggregateStateChanged?(oldState, aggregateState)

            // 延迟刷新 token 数据（压缩完成后 context 已重置）
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))

                // 重置冷却以确保压缩后立即查询
                self.lastOpenCodeQueryTime.removeValue(forKey: session.cwd)

                // 压缩完成后恢复到 coding 状态，并从 OpenCode DB 刷新 token 数据
                if var updated = self.sessions[sessionId] {
                    if let data = await self.contextMonitor.fetchContextUsageFromOpenCodeDB(cwd: session.cwd) {
                        updated.contextUsage = data.usage
                        updated.contextTokensUsed = data.tokensUsed
                        updated.contextTokensTotal = data.tokensTotal
                        updated.contextInputTokens = data.inputTokens
                        updated.contextOutputTokens = data.outputTokens
                        updated.contextReasoningTokens = data.reasoningTokens
                    }

                    let preRestoreState = self.aggregateState
                    updated.status = .coding
                    try? updated.writeToFile()

                    self.sessions[sessionId] = updated
                    self.recomputeSortedSessions()

                    let newState = self.aggregateState
                    self.onAggregateStateChanged?(preRestoreState, newState)
                }
            }
        }
    }

    /// 更新单个会话状态（文件回调入口）
    private func updateSession(_ sessionId: String, _ session: Session) async {
        let oldState = aggregateState
        var session = session

        // OpenCode 会话：从 SQLite DB 读取最新的 token 使用量（带冷却避免频繁 fork）
        if session.source == "opencode" {
            if let data = await fetchOpenCodeContextIfNeeded(cwd: session.cwd) {
                session.contextUsage = data.usage
                session.contextTokensUsed = data.tokensUsed
                session.contextTokensTotal = data.tokensTotal
                session.contextInputTokens = data.inputTokens
                session.contextOutputTokens = data.outputTokens
                session.contextReasoningTokens = data.reasoningTokens
            }
        }

        sessions[sessionId] = session
        recomputeSortedSessions()

        CodingTimeTracker.shared.handleSessionStateChange(sessionId: sessionId, state: session.status)

        // 编码时长同步由 startCodingTimeTicker 每 30 秒统一处理（避免双重复计）
        // 此处不再重复调用 PetProgressManager.shared.addCodingMinutes

        // 检测聚合状态变化，触发回调（播放提示音）
        let newState = aggregateState
        if newState != oldState {
            onAggregateStateChanged?(oldState, newState)
        }
    }

    /// 注册外部工具的会话（OpenCode 等）
    /// - Parameter session: 外部工具会话（sessionId 已由调用方加前缀，如 "opencode_xxx"）
    func registerExternalSession(_ session: Session) async {
        let oldState = aggregateState
        var session = session

        // 从 OpenCode 数据库读取最新的 token 使用量（带冷却避免频繁 fork）
        if session.source == "opencode" {
            if let data = await fetchOpenCodeContextIfNeeded(cwd: session.cwd) {
                session.contextUsage = data.usage
                session.contextTokensUsed = data.tokensUsed
                session.contextTokensTotal = data.tokensTotal
                session.contextInputTokens = data.inputTokens
                session.contextOutputTokens = data.outputTokens
                session.contextReasoningTokens = data.reasoningTokens
                try? session.writeToFile()
            }
        }

        sessions[session.sessionId] = session
        recomputeSortedSessions()

        Self.logger.debug("注册外部会话: \(session.sessionId) (source: \(session.source ?? "unknown"))")

        // 检测聚合状态变化，触发回调（播放提示音）
        let newState = aggregateState
        if newState != oldState {
            onAggregateStateChanged?(oldState, newState)
        }
    }

    /// 移除外部工具的会话
    /// - Parameter sessionId: 会话 ID（可以是带前缀的 ID）
    func removeExternalSession(_ sessionId: String) {
        sessions.removeValue(forKey: sessionId)
        recomputeSortedSessions()
    }

    /// 使排序缓存失效（sessions 字典变更时调用）
    /// 排序按 lastActivity 降序（最近活跃在前），这是设计意图——
    /// 用户最关心的是最近正在使用的会话，而非状态优先级。
    /// 状态优先级（SessionState.priority）仅用于 aggregateState 聚合计算。
    private func recomputeSortedSessions() {
        sortedSessions = sessions.values.sorted { $0.lastActivity > $1.lastActivity }
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

    /// 是否有 Claude Code 会话（source 为 nil 表示来自 CLI hook）
    var hasClaudeCodeSessions: Bool {
        sessions.values.contains { $0.source == nil || $0.source == "claude" }
    }

    /// 移除已完成的会话
    func removeCompletedSessions() {
        sessions = sessions.filter {
            $0.value.status != .completed
        }
        recomputeSortedSessions()
    }

    /// 清除所有会话
    func clearAll() {
        sessions.removeAll()
        sortedSessions = []
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

    /// 获取所有工具来源的汇总摘要（单次遍历）
    func multiToolSummary() -> String {
        var claudeActive = 0
        var openCodeActive = 0
        var foundError = false
        var foundPermission = false

        for session in sessions.values {
            let isActive = session.status != .completed && session.status != .idle
            if isActive {
                switch session.source {
                case "opencode": openCodeActive += 1
                case "codex": break // Codex 暂不单独计数
                default: claudeActive += 1 // nil (CLI hook) 或 "claude"
                }
            }
            if session.status == .error { foundError = true }
            if session.status == .waitingPermission { foundPermission = true }
        }

        let total = claudeActive + openCodeActive
        guard total > 0 else { return "\u{2713} 无活跃会话" }

        var parts: [String] = []
        if claudeActive > 0 { parts.append("Claude:\(claudeActive)") }
        if openCodeActive > 0 { parts.append("OpenCode:\(openCodeActive)") }

        let prefix: String
        if foundError { prefix = "\u{26A0}\u{FE0F}" }
        else if foundPermission { prefix = "\u{1F512}" }
        else { prefix = "\u{1F528}" }

        return "\(prefix) \(total) 活跃 (\(parts.joined(separator: " | ")))"
    }

// MARK: 跟踪模式切换

    /// 切换到自动跟踪模式
    func setTrackingModeAuto() {
        // 清理之前的手动跟踪会话的 refresh 文件
        if case .manual(let sessionId) = trackingMode {
            cleanupRefreshFile(sessionId: sessionId)
        }
        trackingMode = .auto
        // 持久化到设置
        viewModel?.settings.sessionTrackingMode = "auto"
        viewModel?.settings.pinnedSessionId = nil
        saveSettings()
        Self.logger.info("切换到自动跟踪模式")
    }

    /// 清理 .refresh 标记文件
    private func cleanupRefreshFile(sessionId: String) {
        let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vibe-island/sessions")
        let refreshFile = sessionsDir.appendingPathComponent("\(sessionId).refresh")
        try? FileManager.default.removeItem(at: refreshFile)
    }

    /// 切换到手动跟踪模式，固定指定会话
    /// - Parameter sessionId: 要固定的会话 ID
    func setTrackingModeManual(sessionId: String) {
        // 清理之前的手动跟踪会话的 refresh 文件
        if case .manual(let oldSessionId) = trackingMode, oldSessionId != sessionId {
            cleanupRefreshFile(sessionId: oldSessionId)
        }

        trackingMode = .manual(sessionId: sessionId)

        // 创建刷新标记文件，触发插件同步最新上下文
        let sessionsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vibe-island/sessions")
        try? FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        let refreshFile = sessionsDir.appendingPathComponent("\(sessionId).refresh")
        try? "".write(to: refreshFile, atomically: true, encoding: .utf8)

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
