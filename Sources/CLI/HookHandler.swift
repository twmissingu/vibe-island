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

            // Apply the event to update session state
            session.status = event.hookEventName.toSessionState()

            // Propagate event fields to session
            session.source = resolvedSource ?? session.source
            session.sessionName = event.sessionName ?? session.sessionName
            session.notificationMessage = event.message

            // Parse and persist context usage from PreCompact message or UserPromptSubmit (for token tracking)
            if event.hookEventName == .preCompact || event.hookEventName == .userPromptSubmit {
                if let usage = event.contextUsage {
                    session.contextUsage = usage
                    session.contextTokensUsed = event.contextTokensUsed
                    session.contextTokensTotal = event.contextTokensTotal
                } else if let message = event.message {
                    parseAndStoreContextUsage(message, into: &session)
                }
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
        // Try to load existing session
        if FileManager.default.fileExists(atPath: path.path),
           let existing = try? Session.loadFromFile(url: path) {
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
        FileHandle.standardError.write(message.data(using: .utf8) ?? Data())
    }

    private static func logCleanup(sessionId: String, pid: UInt32?) {
        let pidStr = pid.map { "PID:\($0)" } ?? "PID:unknown"
        let message = "[vibe-island] Cleanup stale session: \(sessionId) (\(pidStr))\n"
        FileHandle.standardError.write(message.data(using: .utf8) ?? Data())
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
