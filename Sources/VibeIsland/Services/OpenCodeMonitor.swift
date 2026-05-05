import Foundation
import OSLog

// MARK: - OpenCode 会话状态

/// OpenCode 会话运行状态，与 SessionState 桥接
enum OpenCodeStatus: String, Codable, Equatable, Sendable {
    case idle               // 空闲，等待输入
    case working            // 正在处理任务
    case waiting            // 等待权限审批
    case completed          // 会话结束
    case error              // 错误 / 中止
    case retrying           // 重试中

    /// 映射到 SessionState
    var toSessionState: SessionState {
        switch self {
        case .idle: return .idle
        case .working: return .coding
        case .waiting: return .waitingPermission
        case .completed: return .completed
        case .error: return .error
        case .retrying: return .thinking
        }
    }
}

// MARK: - OpenCode 会话模型

/// OpenCode 会话快照
struct OpenCodeSession: Equatable, Sendable {
    /// 会话 ID
    let sessionId: String
    /// 当前工作目录
    let cwd: String
    /// 会话状态
    var status: OpenCodeStatus
    /// 最后活动时间
    var lastActivity: Date
    /// 当前工具名
    var currentTool: String?
    /// 通知消息
    var message: String?
    /// 进程 ID
    var pid: Int?
    /// 数据来源
    let source: OpenCodeMonitorSource

    /// 转换为 Session 模型
    func toSession() -> Session {
        Session(
            sessionId: "opencode-\(sessionId)",
            cwd: cwd,
            status: status.toSessionState,
            lastActivity: lastActivity,
            source: "opencode",
            sessionName: "OpenCode: \(cwd.split(separator: "/").last?.description ?? cwd)",
            lastTool: currentTool,
            notificationMessage: message
        )
    }
}

// MARK: - 数据来源枚举

/// OpenCode 监控数据来源（仅插件）
enum OpenCodeMonitorSource: String, Sendable {
    case plugin             // 插件 Hook（唯一数据源）
}

// MARK: - OpenCode 监控服务

/// OpenCode 监控服务，仅通过插件 Hook 获取状态
///
/// 工作原理：
/// 监听 OpenCode 插件写入的 session 文件（~/.vibe-island/opencode-sessions/）
/// 插件会在 OpenCode 运行时自动加载，写入状态变化到 JSON 文件
@MainActor
@Observable
final class OpenCodeMonitor: SessionAggregatable {
    // MARK: SessionAggregatable 实现
    var allSessions: [OpenCodeSession] { sessions }
    func sessionStatus(_ session: OpenCodeSession) -> SessionState { session.status.toSessionState }

    // MARK: 常量

    /// OpenCode 插件 session 目录（~/.vibe-island/opencode-sessions/）
    static let pluginSessionsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".vibe-island")
        .appendingPathComponent("opencode-sessions")

    // MARK: 单例

    static let shared = OpenCodeMonitor()

    // MARK: 公开状态

    /// 当前活跃会话
    private(set) var sessions: [OpenCodeSession] = []

    /// 当前使用的数据源
    private(set) var currentSource: OpenCodeMonitorSource = .plugin

    /// 监控是否已启动
    private(set) var isRunning = false

    /// 插件是否可用（目录存在且可读）
    private(set) var isPluginAvailable = false

    // MARK: 内部依赖

    private let processDetector = ProcessDetector()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "OpenCodeMonitor"
    )

    // MARK: 内部状态

    private var pluginFileWatcher: OpenCodePluginFileWatcher?
    private var hasSetup = false

    // MARK: 初始化

    private init() {}

    // MARK: 生命周期

    /// 启动监控
    func start() {
        guard !hasSetup else { return }
        hasSetup = true

        // 确保插件 session 目录存在
        try? FileManager.default.createDirectory(
            at: Self.pluginSessionsDirectory,
            withIntermediateDirectories: true
        )

        // 检测插件可用性
        isPluginAvailable = FileManager.default.fileExists(atPath: Self.pluginSessionsDirectory.path)

        guard isPluginAvailable else {
            Self.logger.warning("OpenCode 插件目录不存在，请先安装插件")
            isRunning = false
            return
        }

        isRunning = true
        currentSource = .plugin

        // 启动插件文件监听
        let watcher = OpenCodePluginFileWatcher(directory: Self.pluginSessionsDirectory)
        watcher.onSessionsChanged = { [weak self] sessions in
            Task { @MainActor in
                self?.sessions = sessions
                await self?.syncToSessionManager(sessions)
            }
        }
        watcher.startWatching()
        pluginFileWatcher = watcher

        // 立即扫描一次
        scanPluginSessions()

        Self.logger.info("OpenCodeMonitor 已启动（插件模式）")
    }

    /// 停止监控
    func stop() {
        hasSetup = false
        isRunning = false

        pluginFileWatcher?.stopWatching()
        pluginFileWatcher = nil

        // 清理 SessionManager 中注册的外部会话
        cleanupSessionManagerSessions()

        sessions.removeAll()
        isPluginAvailable = false

        Self.logger.info("OpenCodeMonitor 已停止")
    }

    // MARK: - 同步到 SessionManager

    /// 从会话文件读取最新的 context usage 数据
    private func readContextUsageFromFile(for sessionId: String) -> (usage: Double, tokensUsed: Int?, tokensTotal: Int?, inputTokens: Int?, outputTokens: Int?, reasoningTokens: Int?)? {
        let sessionsDir = SessionFileWatcher.sessionsDirectory

        guard let enumerator = FileManager.default.enumerator(
            at: sessionsDir,
            includingPropertiesForKeys: nil
        ) else { return nil }

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "json" else { continue }

            do {
                let data = try Data(contentsOf: fileURL)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }

                let fileSessionId = json["session_id"] as? String
                guard fileSessionId == sessionId else { continue }

                if let usage = json["context_usage"] as? Double {
                    let tokensUsed = json["context_tokens_used"] as? Int
                    let tokensTotal = json["context_tokens_total"] as? Int
                    let inputTokens = json["context_input_tokens"] as? Int
                    let outputTokens = json["context_output_tokens"] as? Int
                    let reasoningTokens = json["context_reasoning_tokens"] as? Int
                    return (usage, tokensUsed, tokensTotal, inputTokens, outputTokens, reasoningTokens)
                }
            } catch {
                continue
            }
        }
        return nil
    }

    /// 将 OpenCode 会话同步注册到 SessionManager
    private func syncToSessionManager(_ openCodeSessions: [OpenCodeSession]) async {
        let sm = SessionManager.shared

        for session in openCodeSessions {
            let sessionId = "opencode-\(session.sessionId)"
            var sessionData = session.toSession()

            // 从会话文件读取最新的 context usage 数据
            if let contextData = readContextUsageFromFile(for: sessionId) {
                sessionData.contextUsage = contextData.usage
                sessionData.contextTokensUsed = contextData.tokensUsed
                sessionData.contextTokensTotal = contextData.tokensTotal
                sessionData.contextInputTokens = contextData.inputTokens
                sessionData.contextOutputTokens = contextData.outputTokens
                sessionData.contextReasoningTokens = contextData.reasoningTokens
            }

            await sm.registerExternalSession(sessionData)
        }

        // 清理不再存在的会话
        let currentIds = Set(openCodeSessions.map { "opencode-\($0.sessionId)" })
        let staleIds = sm.sessions(from: "opencode").map(\.sessionId).filter { !currentIds.contains($0) }
        for id in staleIds {
            sm.removeExternalSession(id)
        }
    }

    /// 停止时清理 SessionManager 中所有 OpenCode 会话
    private func cleanupSessionManagerSessions() {
        Task { @MainActor in
            await syncToSessionManager([])
        }
    }

    /// 手动刷新
    func refresh() {
        scanPluginSessions()
    }

    // MARK: 插件文件扫描

    /// 扫描插件写入的 session 文件
    private func scanPluginSessions() {
        let directory = Self.pluginSessionsDirectory
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var foundSessions: [OpenCodeSession] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "json" else { continue }
            if let session = parsePluginSessionFile(fileURL) {
                foundSessions.append(session)
            }
        }

        // 验证 PID 存活，过滤僵尸会话
        let aliveSessions = foundSessions.filter { session in
            guard let pid = session.pid else { return true }
            return processDetector.isProcessRunning(pid: pid)
        }

        sessions = aliveSessions
    }

    /// 解析插件写入的 session JSON
    private func parsePluginSessionFile(_ url: URL) -> OpenCodeSession? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let pluginSession = try? decoder.decode(PluginSessionFile.self, from: data) {
            return pluginSession.toOpenCodeSession(fileURL: url)
        }

        return nil
    }

    // MARK: - 生成安装提示

    /// 生成安装插件的 shell 脚本建议
    static var pluginInstallScript: String {
        """
        #!/bin/bash
        # 安装 OpenCode 监控插件
        PLUGIN_DIR="$HOME/.config/opencode/plugins"
        mkdir -p "$PLUGIN_DIR"
        # 将 vibe-island.js 复制到插件目录
        # cp vibe-island-opencode-plugin.js "$PLUGIN_DIR/vibe-island.js"
        echo "OpenCode 监控插件安装目录: $PLUGIN_DIR"
        """
    }
}

// MARK: - 插件 Session 文件格式

/// 插件写入的 session 文件格式（参考 cctop 格式）
struct PluginSessionFile: Codable {
    let sessionID: String
    let cwd: String
    let status: String
    let lastActive: TimeInterval?
    let pid: Int?
    let projectName: String?
    let currentTool: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "sessionID"
        case cwd
        case status
        case lastActive = "lastActive"
        case pid
        case projectName = "projectName"
        case currentTool = "currentTool"
        case message
    }

    func toOpenCodeSession(fileURL: URL) -> OpenCodeSession {
        let status = OpenCodeStatus(rawValue: status) ?? .idle
        let lastActivity = lastActive.map { Date(timeIntervalSince1970: $0 / 1000.0) } ?? Date()

        return OpenCodeSession(
            sessionId: sessionID,
            cwd: cwd,
            status: status,
            lastActivity: lastActivity,
            currentTool: currentTool,
            message: message,
            pid: pid,
            source: .plugin
        )
    }
}

// MARK: - OpenCode 插件文件监听器

/// 监听插件写入的 session 文件目录
@MainActor
final class OpenCodePluginFileWatcher {

    // MARK: 属性

    private let directory: URL
    var onSessionsChanged: (([OpenCodeSession]) -> Void)?
    private var pollingTask: Task<Void, Never>?
    private var isWatching = false
    private var lastModDates: [URL: Date] = [:]

    private static let pollingInterval: TimeInterval = 2.0

    // MARK: 初始化

    init(directory: URL) {
        self.directory = directory
    }

    deinit {
        isWatching = false
        pollingTask?.cancel()
    }

    // MARK: 公开方法

    func startWatching() {
        guard !isWatching else { return }
        isWatching = true
        startPolling()
    }

    func stopWatching() {
        isWatching = false
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: 轮询

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollingInterval))
                guard !Task.isCancelled else { break }
                await self.pollForChanges()
            }
        }
    }

    private func pollForChanges() async {
        guard isWatching else { return }

        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter({ $0.pathExtension == "json" }) else { return }

        var currentModDates: [URL: Date] = [:]
        var hasChanges = false

        for fileURL in files {
            do {
                let attrs = try fm.attributesOfItem(atPath: fileURL.path)
                if let modDate = attrs[.modificationDate] as? Date {
                    currentModDates[fileURL] = modDate
                    if lastModDates[fileURL] != modDate {
                        hasChanges = true
                    }
                }
            } catch {
                // 忽略单个文件错误
            }
        }

        // 检查删除
        let removedFiles = lastModDates.keys.filter { !currentModDates.keys.contains($0) }
        if !removedFiles.isEmpty {
            hasChanges = true
        }

        lastModDates = currentModDates

        if hasChanges {
            scanAndNotify()
        }
    }

    private func scanAndNotify() {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        var sessions: [OpenCodeSession] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "json" else { continue }
            if let session = parseFile(fileURL) {
                sessions.append(session)
            }
        }

        Task { @MainActor in
            onSessionsChanged?(sessions)
        }
    }

    private func parseFile(_ url: URL) -> OpenCodeSession? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let plugin = try? decoder.decode(PluginSessionFile.self, from: data) {
            return plugin.toOpenCodeSession(fileURL: url)
        }

        return nil
    }
}

// MARK: - ProcessDetector 扩展

extension ProcessDetector {
    /// 检测指定 PID 的进程是否仍在运行
    func isProcessRunning(pid: Int) -> Bool {
        return kill(pid_t(pid), 0) == 0
    }
}
