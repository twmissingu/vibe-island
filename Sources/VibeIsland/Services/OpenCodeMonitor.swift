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

// MARK: - 辅助类型

/// 简单的可变容器，用于跨闭包传递值
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(value: T) { self.value = value }
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
            sessionId: "opencode_\(sessionId)",
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

/// OpenCode 监控数据来源（四级降级）
enum OpenCodeMonitorSource: String, Sendable {
    case plugin             // 插件 Hook（首选）
    case sse                // SSE 事件订阅
    case file               // 文件监听降级
    case process            // 进程检测兜底
}

// MARK: - OpenCode 监控服务

/// OpenCode 监控服务，实现四级降级架构：
///   Plugin → SSE → 文件 → 进程检测
///
/// 工作原理：
/// 1. 优先检测 OpenCode 插件写入的 session 文件
/// 2. 不可用时尝试 SSE 连接（opencode serve 模式）
/// 3. 降级到监听 OpenCode 原生存储文件
/// 4. 最终兜底：pgrep 检测进程
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

    /// OpenCode 原生存储目录
    static let nativeStoragePath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".local")
        .appendingPathComponent("share")
        .appendingPathComponent("opencode")
        .appendingPathComponent("storage")

    /// SSE 默认端口
    static let defaultSSEPort = 4040

    /// 检测间隔（秒）
    static let defaultCheckInterval: TimeInterval = 5.0

    // MARK: 单例

    static let shared = OpenCodeMonitor()

    // MARK: 公开状态

    /// 当前活跃会话
    private(set) var sessions: [OpenCodeSession] = []

    /// 当前使用的数据源
    private(set) var currentSource: OpenCodeMonitorSource = .process

    /// 监控是否已启动
    private(set) var isRunning = false



    // MARK: 内部依赖

    private let processDetector = ProcessDetector()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "OpenCodeMonitor"
    )

    // MARK: 内部状态

    private var pluginFileWatcher: SessionFileWatcher?
    private var sseClient: OpenCodeSSEClient?
    private var checkTimer: Timer?
    private var hasSetup = false

    // MARK: 初始化

    private init() {}

    // MARK: 生命周期

    /// 启动监控
    func start() {
        guard !hasSetup else { return }
        hasSetup = true
        isRunning = true

        // 创建插件 session 目录
        try? FileManager.default.createDirectory(
            at: Self.pluginSessionsDirectory,
            withIntermediateDirectories: true
        )

        // 按优先级尝试各数据源
        attemptPluginSource()
        attemptSSESource()
        startFallbackProcessCheck()

        Self.logger.info("OpenCodeMonitor 已启动")
    }

    /// 停止监控
    func stop() {
        hasSetup = false
        isRunning = false

        pluginFileWatcher?.stopWatching()
        pluginFileWatcher = nil

        sseClient?.disconnect()
        sseClient = nil

        checkTimer?.invalidate()
        checkTimer = nil

        sessions.removeAll()
        currentSource = .process

        Self.logger.info("OpenCodeMonitor 已停止")
    }

    /// 手动刷新
    func refresh() {
        scanPluginSessions()
        scanNativeStorage()
        checkProcessStatus()
    }

    // MARK: 级别 1：插件 Hook 数据源

    /// 尝试使用插件文件监听方案
    private func attemptPluginSource() {
        let directory = Self.pluginSessionsDirectory

        // 检查目录是否存在
        guard FileManager.default.fileExists(atPath: directory.path) else {
            Self.logger.debug("插件 session 目录不存在，跳过插件方案")
            return
        }

        Self.logger.info("使用插件文件监听方案")
        currentSource = .plugin

        // 创建专用文件监听器
        let watcher = OpenCodePluginFileWatcher(directory: directory)
        watcher.onSessionsChanged = { [weak self] sessions in
            Task { @MainActor in
                self?.updateSessions(sessions, source: .plugin)
            }
        }
        watcher.startWatching()
        pluginFileWatcher = SessionFileWatcher()

        // 立即扫描
        scanPluginSessions()
    }

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

        if !aliveSessions.isEmpty || currentSource == .plugin {
            updateSessions(aliveSessions, source: .plugin)
        }
    }

    /// 解析插件写入的 session JSON
    private func parsePluginSessionFile(_ url: URL) -> OpenCodeSession? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 尝试解析插件格式
        if let pluginSession = try? decoder.decode(PluginSessionFile.self, from: data) {
            return pluginSession.toOpenCodeSession(fileURL: url)
        }

        return nil
    }

    // MARK: 级别 2：SSE 数据源

    /// 尝试使用 SSE 方案
    private func attemptSSESource() {
        // 动态发现 OpenCode SSE 端口
        let ssePort = discoverOpenCodeSSEPort() ?? Self.defaultSSEPort
        
        // 检测 SSE 服务是否可达
        guard isSSEReachable(port: ssePort) else {
            Self.logger.debug("SSE 服务不可达（端口 \(ssePort)），跳过 SSE 方案")
            return
        }

        Self.logger.info("使用 SSE 事件订阅方案（端口 \(ssePort)）")
        currentSource = .sse

        let client = OpenCodeSSEClient(port: ssePort)
        client.onSessionsChanged = { [weak self] sessions in
            Task { @MainActor in
                self?.updateSessions(sessions, source: .sse)
            }
        }
        client.connect()
        sseClient = client
    }

    /// 动态发现 OpenCode SSE 端口
    private func discoverOpenCodeSSEPort() -> Int? {
        // 使用 lsof 查找 opencode 进程监听的端口
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", "-P", "-n"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            guard let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) else {
                return nil
            }
            
            // 查找 opencode 进程的 LISTEN 端口
            for line in output.split(separator: "\n") {
                if line.contains("opencode") && line.contains("LISTEN") {
                    // 格式: opencode PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
                    // NAME 列格式: localhost:PORT (LISTEN)
                    let parts = line.split(separator: " ").filter { !$0.isEmpty }
                    if let namePart = parts.last {
                        // 提取端口号
                        if let portRange = namePart.range(of: ":(\\d+)", options: .regularExpression) {
                            let portStr = String(namePart[portRange]).dropFirst() // 去掉 ":"
                            return Int(portStr)
                        }
                    }
                }
            }
        } catch {
            Self.logger.error("lsof 执行失败: \(error.localizedDescription)")
        }
        
        return nil
    }

    /// 检测 SSE 服务是否可达
    private func isSSEReachable(port: Int) -> Bool {
        let url = URL(string: "http://localhost:\(port)/global/event")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.0

        let semaphore = DispatchSemaphore(value: 0)
        let resultBox: Box<Bool> = Box(value: false)

        let task = URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse,
               (200...499).contains(httpResponse.statusCode) {
                resultBox.value = true
            }
            semaphore.signal()
        }
        task.resume()

        // 等待最多 3 秒
        _ = semaphore.wait(timeout: .now() + 3)
        return resultBox.value
    }

    // MARK: 级别 3：文件监听降级

    /// 扫描 OpenCode 原生存储文件
    private func scanNativeStorage() {
        let storagePath = Self.nativeStoragePath
        guard FileManager.default.fileExists(atPath: storagePath.path) else { return }

        // 如果当前不是更高级的数据源，才使用文件方案
        guard currentSource == .process || currentSource == .file else { return }

        Self.logger.debug("使用原生存储文件监听方案")
        currentSource = .file

        // 扫描 storage 目录下的 session 数据
        guard let enumerator = FileManager.default.enumerator(
            at: storagePath,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var foundSessions: [OpenCodeSession] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "json" else { continue }
            if let session = parseNativeSessionFile(fileURL) {
                foundSessions.append(session)
            }
        }

        updateSessions(foundSessions, source: .file)
    }

    /// 解析 OpenCode 原生 session 文件
    private func parseNativeSessionFile(_ url: URL) -> OpenCodeSession? {
        guard let data = try? Data(contentsOf: url) else { return nil }

        // 尝试多种格式
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // 格式 1：直接解析为 PluginSessionFile
        if let session = try? decoder.decode(PluginSessionFile.self, from: data) {
            return session.toOpenCodeSession(fileURL: url)
        }

        // 格式 2：解析为通用字典并推断
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parseGenericJSON(json, fileURL: url)
        }

        return nil
    }

    /// 从通用 JSON 字典推断 session 信息
    private func parseGenericJSON(_ json: [String: Any], fileURL: URL) -> OpenCodeSession? {
        let sessionId = json["sessionID"] as? String
            ?? json["session_id"] as? String
            ?? json["id"] as? String
            ?? fileURL.deletingPathExtension().lastPathComponent

        let cwd = json["cwd"] as? String
            ?? FileManager.default.currentDirectoryPath

        let statusStr = json["status"] as? String ?? "idle"
        let status = OpenCodeStatus(rawValue: statusStr) ?? .idle

        let currentTool = json["currentTool"] as? String ?? json["toolName"] as? String
        let message = json["message"] as? String

        return OpenCodeSession(
            sessionId: sessionId,
            cwd: cwd,
            status: status,
            lastActivity: Date(),
            currentTool: currentTool,
            message: message,
            pid: nil,
            source: .file
        )
    }

    // MARK: 级别 4：进程检测兜底

    /// 启动降级进程检测
    private func startFallbackProcessCheck() {
        checkTimer = Timer.scheduledTimer(
            withTimeInterval: Self.defaultCheckInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkProcessStatus()
            }
        }

        // 立即执行一次
        checkProcessStatus()
    }

    /// 检查 OpenCode 进程状态
    private func checkProcessStatus() {
        // 如果已有更高级数据源在提供数据，跳过进程检测更新
        if !sessions.isEmpty && currentSource != .process {
            return
        }

        let isRunning = isOpenCodeRunning()

        if isRunning && sessions.isEmpty {
            // 仅显示进程存在状态
            let session = OpenCodeSession(
                sessionId: "opencode_process",
                cwd: FileManager.default.currentDirectoryPath,
                status: .idle,
                lastActivity: Date(),
                currentTool: nil,
                message: nil,
                pid: nil,
                source: .process
            )
            updateSessions([session], source: .process)
        } else if !isRunning && currentSource == .process {
            // 进程不存在，清空会话
            updateSessions([], source: .process)
        }
    }

    // MARK: 辅助方法

    /// 更新会话列表
    private func updateSessions(_ newSessions: [OpenCodeSession], source: OpenCodeMonitorSource) {
        // 仅在数据源优先级更高或相同时才更新
        if source.priority <= currentSource.priority || sessions.isEmpty {
            sessions = newSessions
            currentSource = source
        }
    }

    /// 检测 OpenCode 进程是否正在运行
    func isOpenCodeRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "opencode"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            Self.logger.error("pgrep 执行失败: \(error.localizedDescription)")
            return false
        }
    }

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
        // TODO: 清理 pluginFileWatcher
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

    // MARK: 降级轮询

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

// MARK: - OpenCode SSE 客户端

/// SSE 事件流客户端，用于连接 OpenCode serve 模式
@MainActor
final class OpenCodeSSEClient {

    // MARK: 属性

    private let port: Int
    var onSessionsChanged: (([OpenCodeSession]) -> Void)?

    private var dataTask: URLSessionDataTask?
    private var buffer = ""
    
    // 并发安全保护
    @ObservationIgnored private let sessionsLock = NSLock()
    private var activeSessions: [String: OpenCodeSession] = [:]
    
    @ObservationIgnored private let reconnectLock = NSLock()
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.twmissingu.VibeIsland",
        category: "OpenCodeSSEClient"
    )

    // MARK: 初始化

    init(port: Int = OpenCodeMonitor.defaultSSEPort) {
        self.port = port
    }

    deinit {
        // 直接清理
        dataTask?.cancel()
    }

    // MARK: 公开方法

    func connect() {
        disconnect()

        let baseURL = URL(string: "http://localhost:\(port)/global/event")!
        var request = URLRequest(url: baseURL)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("keep-alive", forHTTPHeaderField: "Connection")
        request.timeoutInterval = 0  // SSE 长连接无超时

        dataTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            if let error {
                Task { @MainActor in
                    Self.logger.warning("SSE 连接错误: \(error.localizedDescription)")
                    self.handleDisconnect()
                }
                return
            }

            guard let data, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self.buffer += chunk
                self.parseSSEEvents()
            }
        }
        dataTask?.resume()
        reconnectLock.lock()
        reconnectAttempts = 0
        reconnectLock.unlock()

        Self.logger.info("SSE 客户端已连接到 localhost:\(self.port)")
    }

    func disconnect() {
        dataTask?.cancel()
        dataTask = nil
        buffer = ""
    }

    // MARK: SSE 解析

    private func parseSSEEvents() {
        let lines = buffer.components(separatedBy: .newlines)
        buffer = ""

        for line in lines {
            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))
            guard let jsonData = jsonStr.data(using: .utf8) else { continue }

            // 格式: {"payload":{"type":"session.created","properties":{...}}}
            if let wrapper = try? JSONDecoder().decode(SSEEventWrapper.self, from: jsonData) {
                handleSSEEvent(wrapper)
            }
        }
    }

    private func handleSSEEvent(_ wrapper: SSEEventWrapper) {
        let eventType = wrapper.payload.type
        let properties = wrapper.payload.properties

        switch eventType {
        case "session.created":
            handleSessionCreated(properties)
        case "session.completed", "session.ended":
            handleSessionCompleted(properties)
        case "session.status":
            handleSessionStatus(properties)
        case "tool.executing", "tool.execute":
            handleToolExecute(properties)
        case "message.completed":
            handleMessageCompleted(properties)
        default:
            break
        }

        notifySessionsChanged()
    }

    private func handleSessionCreated(_ properties: SSEProperties) {
        guard let id = properties.sessionID ?? properties.id else { return }
        let session = OpenCodeSession(
            sessionId: id,
            cwd: properties.cwd ?? "",
            status: .idle,
            lastActivity: Date(),
            currentTool: nil,
            message: nil,
            pid: nil,
            source: .sse
        )
        sessionsLock.lock()
        activeSessions[id] = session
        sessionsLock.unlock()
    }

    private func handleSessionCompleted(_ properties: SSEProperties) {
        guard let id = properties.sessionID ?? properties.id else { return }
        sessionsLock.lock()
        if var session = activeSessions[id] {
            session.status = .completed
            session.lastActivity = Date()
            activeSessions[id] = session
        }
        sessionsLock.unlock()
    }

    private func handleSessionStatus(_ properties: SSEProperties) {
        guard let id = properties.sessionID ?? properties.id,
              let statusStr = properties.status else { return }
        sessionsLock.lock()
        if var session = activeSessions[id] {
            session.status = OpenCodeStatus(rawValue: statusStr) ?? .idle
            session.lastActivity = Date()
            activeSessions[id] = session
        }
        sessionsLock.unlock()
    }

    private func handleToolExecute(_ properties: SSEProperties) {
        guard let id = properties.sessionID ?? properties.id else { return }
        sessionsLock.lock()
        if var session = activeSessions[id] {
            session.currentTool = properties.tool ?? properties.toolName
            session.status = .working
            session.lastActivity = Date()
            activeSessions[id] = session
        }
        sessionsLock.unlock()
    }

    private func handleMessageCompleted(_ properties: SSEProperties) {
        guard let id = properties.sessionID ?? properties.id else { return }
        sessionsLock.lock()
        if var session = activeSessions[id] {
            session.status = .idle
            session.lastActivity = Date()
            activeSessions[id] = session
        }
        sessionsLock.unlock()
    }

    private func notifySessionsChanged() {
        sessionsLock.lock()
        let sessions = Array(activeSessions.values)
        sessionsLock.unlock()
        onSessionsChanged?(sessions)
    }

    // MARK: 重连

    private func handleDisconnect() {
        reconnectLock.lock()
        let currentAttempts = reconnectAttempts
        let shouldContinue = currentAttempts < maxReconnectAttempts
        if shouldContinue {
            reconnectAttempts = currentAttempts + 1
        }
        reconnectLock.unlock()
        
        guard shouldContinue else {
            Self.logger.warning("SSE 重连次数耗尽，停止重连")
            return
        }

        let delay = min(Double(currentAttempts + 1) * 2, 30)  // 指数退避，最大 30s

        Self.logger.info("将在 \(delay)s 后尝试第 \(currentAttempts + 1) 次重连")

        Task {
            try? await Task.sleep(for: .seconds(delay))
            Task { @MainActor in
                connect()
            }
        }
    }
}

// MARK: - SSE 事件解码

struct SSEEventWrapper: Codable {
    let payload: SSEPayload
}

struct SSEPayload: Codable {
    let type: String
    let properties: SSEProperties
}

struct SSEProperties: Codable {
    let sessionID: String?
    let id: String?
    let cwd: String?
    let status: String?
    let tool: String?
    let toolName: String?
    let content: String?

    enum CodingKeys: String, CodingKey {
        case sessionID = "sessionID"
        case id, cwd, status, tool, content
        case toolName = "toolName"
    }
}

// MARK: - 数据源优先级

extension OpenCodeMonitorSource {
    /// 优先级数值（越小越高）
    var priority: Int {
        switch self {
        case .plugin: return 0
        case .sse: return 1
        case .file: return 2
        case .process: return 3
        }
    }
}

// MARK: - ProcessDetector 扩展

extension ProcessDetector {
    /// 检测指定 PID 的进程是否仍在运行
    func isProcessRunning(pid: Int) -> Bool {
        return kill(pid_t(pid), 0) == 0
    }
}
