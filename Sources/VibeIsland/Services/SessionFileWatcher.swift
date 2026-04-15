import Foundation

// MARK: - 文件监听服务

/// 监控 ~/.vibe-island/sessions/ 目录的 JSON 文件变化
/// 使用 DispatchSource 监听文件变化 + 防抖动 + 降级轮询兜底
@MainActor
@Observable
final class SessionFileWatcher {
    // MARK: 单例
    
    static let shared = SessionFileWatcher()
    
    // MARK: 配置

    /// 会话文件目录
    static let sessionsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".vibe-island")
        .appendingPathComponent("sessions")

    /// 防抖动间隔（纳秒）—— 100ms
    private static let debounceInterval: UInt64 = 100_000_000

    /// 降级轮询间隔（秒）
    private static let fallbackPollingInterval: TimeInterval = 5.0

    // MARK: 公开状态

    /// 所有已发现的会话
    private(set) var sessions: [String: Session] = [:]
    /// 监听是否已启动
    private(set) var isWatching = false
    
    /// 聚合状态 - 返回最高优先级的会话状态
    var aggregateState: SessionState {
        guard !sessions.isEmpty else { return .idle }
        return sessions.values
            .map(\.status)
            .sorted { $0.priority < $1.priority }
            .first ?? .idle
    }
    
    /// 优先级最高的会话
    var topSession: Session? {
        guard !sessions.isEmpty else { return nil }
        return sessions.values
            .sorted { $0.status.priority < $1.status.priority }
            .first
    }

    // MARK: 内部状态

    /// DispatchSource 文件监听器（每个文件一个）
    @ObservationIgnored
    private var fileSources: [URL: DispatchSourceFileSystemObject] = [:]
    /// 文件描述符锁，保护 fileSources 并发访问
    @ObservationIgnored
    private let sourcesLock = NSLock()
    /// 防抖动时间戳记录
    @ObservationIgnored
    private var lastEventTimes: [URL: UInt64] = [:]
    @ObservationIgnored
    private let debounceLock = NSLock()

    /// 降级轮询任务
    @ObservationIgnored
    private var pollingTask: Task<Void, Never>?
    /// 文件修改时间快照（用于降级轮询对比）
    @ObservationIgnored
    private var fileModificationDates: [URL: Date] = [:]

    /// 事件回调
    @ObservationIgnored
    private var onSessionUpdated: ((String, Session) -> Void)?

    // MARK: 生命周期

    init() {}

    deinit {
        // 清理 DispatchSources
        sourcesLock.lock()
        for source in fileSources.values {
            source.cancel()
        }
        fileSources.removeAll()
        sourcesLock.unlock()
        
        // 取消轮询任务
        pollingTask?.cancel()
    }

    // MARK: 公开方法

    /// 设置会话更新回调
    func onSessionUpdated(_ handler: @escaping @Sendable (String, Session) -> Void) {
        onSessionUpdated = handler
    }

    /// 启动文件监听
    @MainActor
    func startWatching() {
        guard !isWatching else { return }
        isWatching = true

        // 确保目录存在
        createSessionsDirectoryIfNeeded()

        // 扫描已有文件
        scanExistingFiles()

        // 启动降级轮询
        startFallbackPolling()
    }

    /// 停止文件监听
    @MainActor
    func stopWatching() {
        isWatching = false
        stopFallbackPolling()
        cancelAllSources()
    }

    /// 手动刷新所有会话文件
    @MainActor
    func refreshAll() {
        scanExistingFiles()
    }

    // MARK: 文件扫描

    /// 扫描目录中所有 JSON 文件
    @MainActor
    private func scanExistingFiles() {
        let directory = Self.sessionsDirectory
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var foundURLs: Set<URL> = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "json" else { continue }
            foundURLs.insert(fileURL)

            // 如果还没有监听，创建监听源
            sourcesLock.lock()
            let alreadyWatching = fileSources[fileURL] != nil
            sourcesLock.unlock()

            if !alreadyWatching {
                createDispatchSource(for: fileURL)
            }

            // 立即解析文件
            parseSessionFile(fileURL)
        }

        // 清理已删除文件的监听源
        sourcesLock.lock()
        let removedURLs = fileSources.keys.filter { !foundURLs.contains($0) }
        sourcesLock.unlock()

        for url in removedURLs {
            removeDispatchSource(for: url)
            sessions.removeValue(forKey: url.deletingPathExtension().lastPathComponent)
        }
    }

    // MARK: DispatchSource 管理

    /// 创建 DispatchSource 监听单个文件
    private func createDispatchSource(for fileURL: URL) {
        // 确保文件存在
        if !FileManager.default.fileExists(atPath: fileURL.path) { return }

        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: DispatchQueue.global(qos: .userInitiated)
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                guard let self = self else { return }
                self.handleFileEvent(for: fileURL)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()

        sourcesLock.lock()
        fileSources[fileURL] = source
        sourcesLock.unlock()
    }

    /// 移除 DispatchSource
    private func removeDispatchSource(for fileURL: URL) {
        sourcesLock.lock()
        if let source = fileSources.removeValue(forKey: fileURL) {
            source.cancel()
        }
        sourcesLock.unlock()

        debounceLock.lock()
        lastEventTimes.removeValue(forKey: fileURL)
        debounceLock.unlock()
    }

    /// 取消所有监听源
    private func cancelAllSources() {
        sourcesLock.lock()
        let sources = Array(fileSources.values)
        fileSources.removeAll()
        sourcesLock.unlock()

        sources.forEach { $0.cancel() }

        debounceLock.lock()
        lastEventTimes.removeAll()
        debounceLock.unlock()
    }

    // MARK: 事件处理

    /// 处理文件变化事件（含防抖动）
    @MainActor
    private func handleFileEvent(for fileURL: URL) {
        let now = DispatchTime.now().uptimeNanoseconds

        // 防抖动检查
        debounceLock.lock()
        let lastTime = lastEventTimes[fileURL] ?? 0
        let elapsed = now - lastTime
        guard elapsed > Self.debounceInterval else {
            debounceLock.unlock()
            return
        }
        lastEventTimes[fileURL] = now
        debounceLock.unlock()

        // 解析并更新会话
        parseSessionFile(fileURL)
    }

    // MARK: 文件解析

    /// 解析单个 JSON 文件并更新会话状态
    @MainActor
    private func parseSessionFile(_ fileURL: URL) {
        do {
            let session = try Session.loadFromFile(url: fileURL)
            let sessionId = session.sessionId

            sessions[sessionId] = session
            onSessionUpdated?(sessionId, session)

        } catch {
            // 解析失败时静默忽略（文件可能正在写入中）
        }
    }

    // MARK: 降级轮询

    /// 启动降级轮询（当 DispatchSource 失效时兜底）
    private func startFallbackPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.fallbackPollingInterval))
                guard !Task.isCancelled else { break }
                self.pollForChanges()
            }
        }
    }

    /// 停止降级轮询
    private func stopFallbackPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// 轮询检查文件变化
    @MainActor
    private func pollForChanges() {
        guard isWatching else { return }

        let directory = Self.sessionsDirectory
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var currentModDates: [URL: Date] = [:]

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "json" else { continue }

            do {
                let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                if let modDate = attrs[.modificationDate] as? Date {
                    currentModDates[fileURL] = modDate

                    // 对比修改时间，有变化则重新解析
                    let previousDate = fileModificationDates[fileURL]
                    if previousDate != modDate {
                        parseSessionFile(fileURL)
                    }
                }
            } catch {
                // 忽略单个文件的读取错误
            }
        }

        fileModificationDates = currentModDates
    }

    // MARK: 辅助方法

    private func createSessionsDirectoryIfNeeded() {
        try? FileManager.default.createDirectory(
            at: Self.sessionsDirectory,
            withIntermediateDirectories: true
        )
    }
}
