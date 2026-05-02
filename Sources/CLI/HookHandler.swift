import Foundation

// MARK: - Hook Handler

/// Processes hook events from stdin, updates session files in ~/.vibe-island/sessions/.
///
/// Reference: cctop HookHandler.swift
enum HookHandler {

    // MARK: - Config

    /// Session file directory: ~/.vibe-island/sessions/
    static let sessionsDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vibe-island")
            .appendingPathComponent("sessions")
    }()

    /// Maximum age (seconds) for stale sessions without PID tracking
    private static let noPIDMaxAge: TimeInterval = 300

    /// 日志文件路径: ~/.vibe-island/hook-debug.log
    private static let debugLogFile: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".vibe-island")
            .appendingPathComponent("hook-debug.log")
    }()

    /// 是否启用调试日志（通过环境变量 VIBE_ISLAND_DEBUG=1 开启）
    private static var isDebugEnabled: Bool {
        ProcessInfo.processInfo.environment["VIBE_ISLAND_DEBUG"] == "1"
    }

    // MARK: - Public Entry Point

    /// Handle a single hook event.
    ///
    /// - Parameter event: The parsed `SessionEvent` from stdin JSON
    static func handleEvent(_ event: SessionEvent) throws {
        // Special handling for session end
        if event.hookEventName == .sessionEnd {
            try handleSessionEnd(event)
            return
        }

        // Ensure sessions directory exists
        try createSessionsDirectory()

        let safeId = sanitizeSessionId(event.sessionId)
        let pid = getParentPID()
        let sessionPath = sessionsDirectory.appendingPathComponent("\(pid).json")

        let branch = getCurrentBranch(cwd: event.cwd)
        let pidStart = processStartTime(pid: pid)

        // Lock the session file for the entire read-modify-write cycle.
        // Without this, concurrent hook processes (e.g. SubagentStart + PreToolUse
        // firing simultaneously) race: both read the old file, apply changes
        // independently, and the last writer wins — clobbering the first writer's changes.
        try FileLock.withLock(at: sessionPath) {
            // 识别opencode进程，覆盖source
            let parentProcessName = processName(pid_t(pid))
            let isOpenCodeProcess = parentProcessName.lowercased().contains("opencode")
            let isOpenCodeSession = event.sessionId.lowercased().starts(with: "opencode-")
            let resolvedSource = isOpenCodeProcess || isOpenCodeSession ? "opencode" : event.source
            
            var session = loadOrCreateSession(
                path: sessionPath,
                event: event,
                sessionId: safeId,
                cwd: event.cwd,
                branch: branch,
                pid: pid,
                pidStartTime: pidStart,
                source: resolvedSource
            )

            // Apply the event to update session state (nil means don't change)
            if let newState = event.hookEventName.toSessionState() {
                session.status = newState
            }
            session.lastActivity = Date()

            // Propagate event fields to session
            session.source = resolvedSource ?? session.source
            session.sessionName = event.sessionName ?? session.sessionName
            session.notificationMessage = event.message

            // 存储 transcript_path（SessionStart 事件提供）
            if event.hookEventName == .sessionStart, let tp = event.transcriptPath {
                session.transcriptPath = tp
                session.transcriptOffset = 0
            }

            // 自动查找 transcript_path（如果 SessionStart 未提供）
            if session.transcriptPath == nil, resolvedSource != "opencode" {
                session.transcriptPath = findTranscriptPath(sessionId: safeId, pid: pid)
                if session.transcriptPath != nil {
                    session.transcriptOffset = 0
                }
            }

            // Process context usage data in ALL events (if available)
            if let usage = event.contextUsage {
                session.contextUsage = usage
                session.contextTokensUsed = event.contextTokensUsed
                session.contextTokensTotal = event.contextTokensTotal
                session.contextInputTokens = event.contextInputTokens
                session.contextOutputTokens = event.contextOutputTokens
                session.contextReasoningTokens = event.contextReasoningTokens
            } else if let message = event.message {
                // Fallback: parse from message if no direct context usage fields
                parseAndStoreContextUsage(message, into: &session)
            }

            // 从 transcript JSONL 解析上下文使用量（Claude Code 会话）
            if resolvedSource != "opencode", let transcriptPath = session.transcriptPath {
                parseTranscriptContext(into: &session, transcriptPath: transcriptPath)
            }

            // FIRST: Increment tool usage count in PreToolUse events
            if event.hookEventName == .preToolUse, let toolName = event.toolName {
                updateToolUsage(&session, toolName: toolName)
            }

            // THEN: Merge tool and skill usage from event if present
            if let eventToolUsage = event.toolUsage {
                mergeToolUsage(&session, with: eventToolUsage)
            }
            if let skillUsage = event.skillUsage {
                session.skillUsage = skillUsage
            }

            // FINALLY: Sort tool usage once after all updates
            if var toolUsage = session.toolUsage {
                session.toolUsage = sortedToolUsage(toolUsage)
            }

            // Ensure PID tracking is always current
            session.pid = pid
            session.pidStartTime = pidStart

            // Write
            try session.writeToFile()

            // Log to stderr
            logEvent(eventName: event.hookEventName.rawValue, sessionId: safeId, pid: pid,
                     cwd: event.cwd, newStatus: session.status.rawValue)
        }

        // Cleanup runs outside the lock — it scans all session files and makes
        // sysctl calls per file, which would unnecessarily hold the lock.
        if event.hookEventName == .sessionStart {
            try? cleanupStaleSessions(projectPath: event.cwd, currentPid: pid)
        }
    }

    // MARK: - Session End

    private static func handleSessionEnd(_ event: SessionEvent) throws {
        let safeId = sanitizeSessionId(event.sessionId)
        let pid = getParentPID()
        let sessionPath = sessionsDirectory.appendingPathComponent("\(pid).json")

        try? FileLock.withLock(at: sessionPath) {
            if var session = try? Session.loadFromFile(url: sessionPath) {
                session.status = .completed
                session.lastActivity = Date()
                try? session.writeToFile()
                logEvent(eventName: event.hookEventName.rawValue, sessionId: safeId,
                         pid: pid, cwd: event.cwd, newStatus: "completed")
            } else {
                // No session file — remove if exists
                try? FileManager.default.removeItem(at: sessionPath)
                logEvent(eventName: event.hookEventName.rawValue, sessionId: safeId,
                         pid: pid, cwd: event.cwd, newStatus: "removed")
            }
        }
    }

    // MARK: - Session Loading

    private static func loadOrCreateSession(
        path: URL,
        event: SessionEvent,
        sessionId: String,
        cwd: String,
        branch: String?,
        pid: UInt32,
        pidStartTime: TimeInterval?,
        source: String?
    ) -> Session {
        // Try to load existing session (no TOCTOU check - just try to load)
        if let existing = try? Session.loadFromFile(url: path) {
            // Check PID reuse: different process start time means a new process reused this PID
            if event.hookEventName == .sessionStart,
               let currentStart = pidStartTime,
               let storedStart = existing.pidStartTime,
               storedStart > currentStart + 1.0 || currentStart > storedStart + 1.0 {
                return createFreshSession(sessionId: sessionId, cwd: cwd, branch: branch,
                                          pid: pid, pidStartTime: pidStartTime, path: path, source: source)
            }
            // Same process, same session ID — return existing
            if existing.sessionId == sessionId {
                var s = existing
                s.fileURL = path
                return s
            }
            // Same process, new session ID (e.g. resume) — carry over state with new ID
            var updated = existing
            updated.fileURL = path
            return updated
        }

        return createFreshSession(sessionId: sessionId, cwd: cwd, branch: branch,
                                  pid: pid, pidStartTime: pidStartTime, path: path, source: source)
    }

    private static func createFreshSession(
        sessionId: String,
        cwd: String,
        branch: String?,
        pid: UInt32,
        pidStartTime: TimeInterval?,
        path: URL,
        source: String?
    ) -> Session {
        Session(
            sessionId: sessionId,
            cwd: cwd,
            status: .idle,
            lastActivity: Date(),
            branch: branch,
            source: source,
            activeSubagents: [],
            pid: pid,
            pidStartTime: pidStartTime,
            fileURL: path
        )
    }

    // MARK: - PID Helpers

    /// Walk up the process tree past shell intermediaries to find the parent process.
    /// When invoked through a hook script, getppid() may return a short-lived /bin/sh PID.
    /// We skip shell processes (sh, bash, zsh) to find the actual parent process.
    static func getParentPID() -> UInt32 {
        let shells: Set<String> = ["sh", "bash", "zsh", "fish", "dash"]
        var pid = getppid()
        for _ in 0..<4 {
            let name = processName(pid)
            if !shells.contains(name) { break }
            let parentPid = parentPIDOf(pid)
            if parentPid <= 1 { break }
            pid = parentPid
        }
        return UInt32(pid)
    }

    /// Get the process start time using sysctl.
    /// Used to detect PID reuse (when a new process gets the same PID as an old one).
    static func processStartTime(pid: UInt32) -> TimeInterval? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else {
            return nil
        }
        // p_starttime is in seconds since epoch
        let startTime = info.kp_proc.p_starttime
        return TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1_000_000
    }

    private static func procInfo(_ pid: pid_t) -> kinfo_proc? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.size
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info
    }

    private static func parentPIDOf(_ pid: pid_t) -> pid_t {
        procInfo(pid)?.kp_eproc.e_ppid ?? 0
    }

    private static func processName(_ pid: pid_t) -> String {
        guard var info = procInfo(pid) else { return "" }
        return withUnsafePointer(to: &info.kp_proc.p_comm) { ptr in
            ptr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN)) { cStr in
                String(cString: cStr)
            }
        }
    }

    // MARK: - Git Branch

    private static func getCurrentBranch(cwd: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["branch", "--show-current"]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let branch = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (branch?.isEmpty ?? true) ? nil : branch
        } catch {
            return nil
        }
    }

    // MARK: - Cleanup

    /// Scan all session files and remove stale ones for the given project path.
    /// A session is stale if:
    ///   - Its PID is no longer alive
    ///   - Its PID has been reused by a different process (different start time)
    ///   - It has no PID and is older than `noPIDMaxAge`
    static func cleanupStaleSessions(projectPath: String, currentPid: UInt32) throws {
        let fm = FileManager.default
        let entries = try fm.contentsOfDirectory(atPath: sessionsDirectory.path)

        for entry in entries where entry.hasSuffix(".json") {
            let path = sessionsDirectory.appendingPathComponent(entry)
            guard let session = try? Session.loadFromFile(url: path) else { continue }

            // Skip sessions for other projects or the current process
            guard session.cwd == projectPath, session.pid != currentPid else { continue }

            let isStale: Bool
            if let pid = session.pid {
                if !isPIDAlive(pid) {
                    isStale = true
                } else if let storedStart = session.pidStartTime,
                          let currentStart = processStartTime(pid: pid),
                          storedStart > currentStart + 1.0 || currentStart > storedStart + 1.0 {
                    isStale = true  // PID reused by a different process
                } else {
                    isStale = false
                }
            } else {
                // No PID tracking — fall back to time-based staleness
                isStale = -session.lastActivity.timeIntervalSinceNow > Self.noPIDMaxAge
            }

            if isStale {
                try? fm.removeItem(at: path)
                try? fm.removeItem(at: path.appendingPathExtension("lock"))
                logCleanup(sessionId: session.sessionId, pid: session.pid)
            }
        }
    }

    private static func isPIDAlive(_ pid: UInt32) -> Bool {
        kill(Int32(pid), 0) == 0 || errno == EPERM
    }

    // MARK: - Session ID Sanitization

    private static func sanitizeSessionId(_ raw: String) -> String {
        // Remove characters that are unsafe for file names
        let unsafe = CharacterSet(charactersIn: "/\\?%*|\"<>")
        return raw.components(separatedBy: unsafe).joined()
    }

    // MARK: - Logging

    private static func logEvent(
        eventName: String, sessionId: String, pid: UInt32, cwd: String, newStatus: String
    ) {
        let label = (cwd as NSString).lastPathComponent
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let message = "[\(timestamp)] [\(eventName)] [\(label)] [PID:\(pid)] -> \(newStatus)\n"
        appendToDebugLog(message)
    }

    private static func logCleanup(sessionId: String, pid: UInt32?) {
        let pidStr = pid.map { "PID:\($0)" } ?? "PID:unknown"
        let message = "[vibe-island] Cleanup stale session: \(sessionId) (\(pidStr))\n"
        appendToDebugLog(message)
    }

    // MARK: - Context Usage Parsing

    /// Parse context usage from PreCompact message and persist to session fields.
    /// Format: "Context usage: 85% (170000/200000 tokens)"
    private static let contextUsagePattern = try? NSRegularExpression(
        pattern: #"(?:Context usage|上下文使用)\s*:\s*(\d+(?:\.\d+)?)\s*%\s*(?:\((\d+)\s*/\s*(\d+)\s*tokens?\))?"#,
        options: .caseInsensitive
    )

    private static func parseAndStoreContextUsage(_ message: String, into session: inout Session) {
        guard let regex = contextUsagePattern else { return }
        let nsString = message as NSString
        let range = NSRange(location: 0, length: nsString.length)
        guard let match = regex.firstMatch(in: message, options: [], range: range) else { return }

        if let percentRange = Range(match.range(at: 1), in: message),
           let percent = Double(message[percentRange]) {
            session.contextUsage = percent / 100.0
        }
        if let usedRange = Range(match.range(at: 2), in: message),
           let used = Int(message[usedRange]) {
            session.contextTokensUsed = used
        }
        if let totalRange = Range(match.range(at: 3), in: message),
           let total = Int(message[totalRange]) {
            session.contextTokensTotal = total
            session.contextLimit = total
        }
    }

    // MARK: - Transcript 路径查找

    /// 自动查找 Claude Code 的 transcript 文件路径
    ///
    /// 查找策略：
    /// 1. 通过 session_id 精确匹配
    /// 2. 通过 PID 查找最近修改的 transcript
    ///
    /// - Parameters:
    ///   - sessionId: 当前会话 ID
    ///   - pid: 当前进程 PID
    /// - Returns: 找到的 transcript 文件路径，未找到返回 nil
    private static func findTranscriptPath(sessionId: String, pid: UInt32) -> String? {
        let claudeProjectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: claudeProjectsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        // 1. 尝试通过 session_id 精确匹配
        for projectDir in projectDirs {
            let jsonlPath = projectDir.appendingPathComponent("\(sessionId).jsonl")
            if FileManager.default.fileExists(atPath: jsonlPath.path) {
                appendToDebugLog("[findTranscriptPath] Found by session_id: \(jsonlPath.path)\n")
                return jsonlPath.path
            }
        }

        // 2. 尝试通过 PID 查找（遍历所有项目的 session 文件，查找最近修改的）
        var candidates: [(path: String, modDate: Date)] = []
        let pidString = String(pid)

        for projectDir in projectDirs {
            guard let enumerator = FileManager.default.enumerator(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                guard fileURL.pathExtension == "jsonl" else { continue }

                // 读取文件内容，检查是否包含当前 PID
                if let data = try? Data(contentsOf: fileURL, options: .mappedIfSafe),
                   let content = String(data: data, encoding: .utf8),
                   content.contains(pidString) {
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                       let modDate = attrs[.modificationDate] as? Date {
                        candidates.append((path: fileURL.path, modDate: modDate))
                    }
                }
            }
        }

        // 返回最近修改的文件
        let result = candidates.sorted { $0.modDate > $1.modDate }.first?.path
        if let result = result {
            appendToDebugLog("[findTranscriptPath] Found by PID \(pid): \(result)\n")
        }
        return result
    }

    // MARK: - Transcript JSONL 解析

    /// 从 Claude Code 的 transcript JSONL 文件解析上下文 token 使用量。
    /// 增量读取：仅处理 offset 之后的新数据，避免重复解析大文件。
    private static func parseTranscriptContext(into session: inout Session, transcriptPath: String) {
        let fileURL = URL(fileURLWithPath: transcriptPath)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: transcriptPath),
              let fileSize = attrs[.size] as? Int, fileSize > 0 else { return }

        var offset = session.transcriptOffset ?? 0

        // 文件变小 = 轮转或替换，重置 offset
        if offset > fileSize { offset = 0 }

        // 无需读取
        guard offset < fileSize else { return }

        // 增量读取，上限 512KB
        let maxRead = 512 * 1024
        let readSize = min(fileSize - offset, maxRead)

        guard let handle = try? FileHandle(forReadingFrom: fileURL) else { return }
        defer { handle.closeFile() }
        handle.seek(toFileOffset: UInt64(offset))
        let newData = handle.readData(ofLength: readSize)

        // 按行扫描，找最后一条含 usage 的 assistant 消息
        var lastInput = 0
        var lastOutput = 0
        var lastCacheRead = 0
        var found = false

        newData.withUnsafeBytes { rawBuffer in
            guard let basePtr = rawBuffer.baseAddress else { return }
            let ptr = basePtr.assumingMemoryBound(to: UInt8.self)
            var lineStart = 0

            for i in 0..<newData.count {
                if ptr[i] == UInt8(ascii: "\n") || i == newData.count - 1 {
                    let lineEnd = (i == newData.count - 1 && ptr[i] != UInt8(ascii: "\n")) ? i + 1 : i
                    if lineEnd > lineStart {
                        let lineData = Data(bytes: ptr + lineStart, count: lineEnd - lineStart)
                        if let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                           let type = json["type"] as? String, type == "assistant",
                           let message = json["message"] as? [String: Any],
                           let usage = message["usage"] as? [String: Any] {
                            let input = usage["input_tokens"] as? Int ?? 0
                            let output = usage["output_tokens"] as? Int ?? 0
                            if input > 0 || output > 0 {
                                lastInput = input
                                lastOutput = output
                                lastCacheRead = usage["cache_read_input_tokens"] as? Int ?? 0
                                found = true
                            }
                        }
                    }
                    lineStart = i + 1
                }
            }
        }

        // 更新 offset
        session.transcriptOffset = fileSize

        guard found else { return }

        let totalUsed = lastInput + lastCacheRead
        session.contextInputTokens = lastInput
        session.contextOutputTokens = lastOutput
        session.contextTokensUsed = totalUsed

        // 上下文上限：使用已缓存的 contextLimit，或模型默认值
        if let limit = session.contextLimit, limit > 0 {
            session.contextTokensTotal = limit
            session.contextUsage = Double(totalUsed) / Double(limit)
        } else {
            let limit = defaultContextLimit()
            session.contextLimit = limit
            session.contextTokensTotal = limit
            session.contextUsage = Double(totalUsed) / Double(limit)
        }
    }

    /// 模型默认上下文窗口大小（Claude 4 系列均为 200K）
    private static func defaultContextLimit() -> Int {
        200_000
    }

    // MARK: - Tool Usage Statistics

    /// Shared: Sort tool usage by count descending
    private static func sortedToolUsage(_ usage: [ToolUsage]) -> [ToolUsage] {
        usage.sorted { $0.count > $1.count }
    }

    /// Update tool usage count for a specific tool
    /// - Parameters:
    ///   - session: The session to update
    ///   - toolName: The name of the tool being used
    private static func updateToolUsage(_ session: inout Session, toolName: String) {
        // Initialize or update tool usage array
        if var existingUsage = session.toolUsage {
            // Find if this tool already exists in the list
            if let index = existingUsage.firstIndex(where: { $0.name == toolName }) {
                // Increment existing count
                let existing = existingUsage[index]
                existingUsage[index] = ToolUsage(name: toolName, count: existing.count + 1)
            } else {
                // Add new tool with count 1
                existingUsage.append(ToolUsage(name: toolName, count: 1))
            }
            session.toolUsage = existingUsage
        } else {
            // No existing usage, create new array with this tool
            session.toolUsage = [ToolUsage(name: toolName, count: 1)]
        }
    }

    /// Merge tool usage from event with existing session data
    /// - Parameters:
    ///   - session: The session to update
    ///   - eventToolUsage: Tool usage data from the event
    private static func mergeToolUsage(_ session: inout Session, with eventToolUsage: [ToolUsage]) {
        if var existingUsage = session.toolUsage {
            // Merge event tool usage with existing
            for eventTool in eventToolUsage {
                if let index = existingUsage.firstIndex(where: { $0.name == eventTool.name }) {
                    // Take the maximum count (event might have more recent/accurate data)
                    let existing = existingUsage[index]
                    existingUsage[index] = ToolUsage(name: eventTool.name, count: max(existing.count, eventTool.count))
                } else {
                    existingUsage.append(eventTool)
                }
            }
            session.toolUsage = existingUsage
        } else {
            // No existing usage, use event data directly
            session.toolUsage = eventToolUsage
        }
    }

    // MARK: - Shared Logging Helper

    private static func appendToDebugLog(_ message: String) {
        guard isDebugEnabled else { return }
        guard let data = message.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: debugLogFile.path) {
            if let fileHandle = try? FileHandle(forWritingTo: debugLogFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: debugLogFile)
        }
    }
}

// MARK: - Helpers

/// Ensure the sessions directory exists.
private func createSessionsDirectory() throws {
    try FileManager.default.createDirectory(
        at: HookHandler.sessionsDirectory,
        withIntermediateDirectories: true
    )
}
