import Foundation

// MARK: - ToolUsage

public struct ToolUsage: Codable, Equatable, Sendable {
    public let name: String
    public let count: Int

    public init(name: String, count: Int) {
        self.name = name
        self.count = count
    }
}

// MARK: - 文件锁工具

public enum FileLock {
    public static func withLock(at url: URL, body: () throws -> Void) throws {
        let lockPath = url.path + ".lock"
        let fd = open(lockPath, O_CREAT | O_WRONLY, 0o600)
        guard fd >= 0 else {
            throw SessionError.lockFailed(String(cString: strerror(errno)))
        }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else {
            throw SessionError.lockFailed(String(cString: strerror(errno)))
        }
        defer { flock(fd, LOCK_UN) }
        try body()
    }
}

// MARK: - 会话状态机

public enum SessionState: String, Codable, Equatable, Sendable, CaseIterable {
    case idle, thinking, coding, waiting, waitingPermission
    case completed, error, compacting

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking"
        case .coding: return "Coding"
        case .waiting: return "Waiting"
        case .waitingPermission: return "Permission"
        case .completed: return "Completed"
        case .error: return "Error"
        case .compacting: return "Compacting"
        }
    }

    public var isBlinking: Bool {
        switch self {
        case .waitingPermission, .compacting: return true
        default: return false
        }
    }

    public static func transition(from current: SessionState, event: SessionEventName) -> SessionState {
        switch event {
        case .sessionStart: return .thinking
        case .userPromptSubmit: return .thinking
        case .preToolUse:
            if current == .thinking || current == .waiting || current == .waitingPermission {
                return .coding
            }
            return current
        case .postToolUse:
            if current == .coding { return .thinking }
            return current
        case .postToolUseFailure: return .error
        case .stop: return .completed
        case .notification: return current
        case .permissionRequest: return .waitingPermission
        case .subagentStart, .subagentStop: return current
        case .preCompact: return .compacting
        case .postCompact:
            if current == .compacting { return .thinking }
            return current
        case .sessionError: return .error
        case .sessionEnd: return .completed
        case .refreshContext: return .coding
        case .contextUpdate: return current
        }
    }

    public var priority: Int {
        switch self {
        case .waitingPermission: return 0
        case .error: return 1
        case .compacting: return 2
        case .coding: return 3
        case .thinking: return 4
        case .waiting: return 5
        case .completed: return 6
        case .idle: return 7
        }
    }
}

// MARK: - Hook 事件名称

public enum SessionEventName: String, Codable, Sendable, CaseIterable {
    case sessionStart = "SessionStart"
    case sessionEnd = "SessionEnd"
    case stop = "Stop"
    case sessionError = "SessionError"
    case userPromptSubmit = "UserPromptSubmit"
    case permissionRequest = "PermissionRequest"
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case postToolUseFailure = "PostToolUseFailure"
    case preCompact = "PreCompact"
    case postCompact = "PostCompact"
    case subagentStart = "SubagentStart"
    case subagentStop = "SubagentStop"
    case notification = "Notification"
    case refreshContext = "RefreshContext"
    case contextUpdate = "ContextUpdate"

    public var displayName: String {
        switch self {
        case .sessionStart: return "会话开始"
        case .sessionEnd: return "会话结束"
        case .stop: return "停止"
        case .sessionError: return "会话错误"
        case .userPromptSubmit: return "用户提交提示"
        case .permissionRequest: return "权限请求"
        case .preToolUse: return "工具调用前"
        case .postToolUse: return "工具调用后"
        case .postToolUseFailure: return "工具调用失败"
        case .preCompact: return "压缩前"
        case .postCompact: return "压缩后"
        case .subagentStart: return "子代理启动"
        case .subagentStop: return "子代理停止"
        case .notification: return "通知"
        case .refreshContext: return "刷新上下文"
        case .contextUpdate: return "上下文更新"
        }
    }

    public func toSessionState() -> SessionState? {
        switch self {
        case .sessionStart: return .idle
        case .userPromptSubmit, .preToolUse, .postToolUse: return .coding
        case .stop: return .completed
        case .notification: return .waiting
        case .permissionRequest: return .waitingPermission
        case .subagentStart, .subagentStop: return .thinking
        case .preCompact, .postCompact: return .compacting
        case .sessionError: return .error
        case .postToolUseFailure: return .error
        case .sessionEnd: return .idle
        case .refreshContext: return .coding
        case .contextUpdate: return nil // nil = don't change state
        }
    }
}

// MARK: - 通知类型

public enum NotificationType: String, Codable, Sendable {
    case idlePrompt = "idle_prompt"
    case permissionPrompt = "permission_prompt"
    case other = "other"
}

// MARK: - Hook 事件数据模型

public struct SessionEvent: Codable, Sendable {
    public let sessionId: String
    public let cwd: String
    public let hookEventName: SessionEventName
    public let source: String?
    public let sessionName: String?
    public let prompt: String?
    public let toolName: String?
    public let toolInput: [String: String]?
    public let title: String?
    public let error: String?
    public let message: String?
    public let notificationType: NotificationType?
    public let agentId: String?
    public let agentType: String?
    public let transcriptPath: String?
    public let permissionMode: String?
    public let isInterrupt: Bool?
    public let pid: UInt32?
    public let pidStartTime: TimeInterval?
    public let contextUsage: Double?
    public let contextTokensUsed: Int?
    public let contextTokensTotal: Int?
    public let contextInputTokens: Int?
    public let contextOutputTokens: Int?
    public let contextReasoningTokens: Int?
    public let toolUsage: [ToolUsage]?
    public let skillUsage: [ToolUsage]?
    public let receivedAt: Date

    public init(
        sessionId: String,
        cwd: String,
        hookEventName: SessionEventName,
        source: String? = nil,
        sessionName: String? = nil,
        prompt: String? = nil,
        toolName: String? = nil,
        toolInput: [String: String]? = nil,
        title: String? = nil,
        error: String? = nil,
        message: String? = nil,
        notificationType: NotificationType? = nil,
        agentId: String? = nil,
        agentType: String? = nil,
        transcriptPath: String? = nil,
        permissionMode: String? = nil,
        isInterrupt: Bool? = nil,
        pid: UInt32? = nil,
        pidStartTime: TimeInterval? = nil,
        contextUsage: Double? = nil,
        contextTokensUsed: Int? = nil,
        contextTokensTotal: Int? = nil,
        contextInputTokens: Int? = nil,
        contextOutputTokens: Int? = nil,
        contextReasoningTokens: Int? = nil,
        toolUsage: [ToolUsage]? = nil,
        skillUsage: [ToolUsage]? = nil,
        receivedAt: Date = Date()
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.hookEventName = hookEventName
        self.source = source
        self.sessionName = sessionName
        self.prompt = prompt
        self.toolName = toolName
        self.toolInput = toolInput
        self.title = title
        self.error = error
        self.message = message
        self.notificationType = notificationType
        self.agentId = agentId
        self.agentType = agentType
        self.transcriptPath = transcriptPath
        self.permissionMode = permissionMode
        self.isInterrupt = isInterrupt
        self.pid = pid
        self.pidStartTime = pidStartTime
        self.contextUsage = contextUsage
        self.contextTokensUsed = contextTokensUsed
        self.contextTokensTotal = contextTokensTotal
        self.contextInputTokens = contextInputTokens
        self.contextOutputTokens = contextOutputTokens
        self.contextReasoningTokens = contextReasoningTokens
        self.toolUsage = toolUsage
        self.skillUsage = skillUsage
        self.receivedAt = receivedAt
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case cwd
        case hookEventName = "hook_event_name"
        case source
        case sessionName = "session_name"
        case prompt
        case toolName = "tool_name"
        case toolInput = "tool_input"
        case title
        case error
        case message
        case notificationType = "notification_type"
        case agentId = "agent_id"
        case agentType = "agent_type"
        case transcriptPath = "transcript_path"
        case permissionMode = "permission_mode"
        case isInterrupt = "is_interrupt"
        case pid
        case pidStartTime = "pid_start_time"
        case contextUsage = "context_usage"
        case contextTokensUsed = "context_tokens_used"
        case contextTokensTotal = "context_tokens_total"
        case contextInputTokens = "context_input_tokens"
        case contextOutputTokens = "context_output_tokens"
        case contextReasoningTokens = "context_reasoning_tokens"
        case toolUsage = "tool_usage"
        case skillUsage = "skill_usage"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        cwd = try container.decode(String.self, forKey: .cwd)
        hookEventName = try container.decode(SessionEventName.self, forKey: .hookEventName)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        sessionName = try container.decodeIfPresent(String.self, forKey: .sessionName)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
        toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
        toolInput = try container.decodeIfPresent([String: String].self, forKey: .toolInput)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        notificationType = try container.decodeIfPresent(NotificationType.self, forKey: .notificationType)
        agentId = try container.decodeIfPresent(String.self, forKey: .agentId)
        agentType = try container.decodeIfPresent(String.self, forKey: .agentType)
        transcriptPath = try container.decodeIfPresent(String.self, forKey: .transcriptPath)
        permissionMode = try container.decodeIfPresent(String.self, forKey: .permissionMode)
        isInterrupt = try container.decodeIfPresent(Bool.self, forKey: .isInterrupt)
        pid = try container.decodeIfPresent(UInt32.self, forKey: .pid)
        pidStartTime = try container.decodeIfPresent(TimeInterval.self, forKey: .pidStartTime)
        contextUsage = try container.decodeIfPresent(Double.self, forKey: .contextUsage)
        contextTokensUsed = try container.decodeIfPresent(Int.self, forKey: .contextTokensUsed)
        contextTokensTotal = try container.decodeIfPresent(Int.self, forKey: .contextTokensTotal)
        contextInputTokens = try container.decodeIfPresent(Int.self, forKey: .contextInputTokens)
        contextOutputTokens = try container.decodeIfPresent(Int.self, forKey: .contextOutputTokens)
        contextReasoningTokens = try container.decodeIfPresent(Int.self, forKey: .contextReasoningTokens)
        toolUsage = try container.decodeIfPresent([ToolUsage].self, forKey: .toolUsage)
        skillUsage = try container.decodeIfPresent([ToolUsage].self, forKey: .skillUsage)
        receivedAt = Date()
    }
}

// MARK: - 子代理信息

public struct SubagentInfo: Codable, Equatable, Sendable {
    public let agentId: String
    public let agentType: String
    public let startedAt: Date

    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case agentType = "agent_type"
        case startedAt = "started_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        agentId = try container.decode(String.self, forKey: .agentId)
        agentType = try container.decodeIfPresent(String.self, forKey: .agentType) ?? "unknown"
        startedAt = try container.decode(Date.self, forKey: .startedAt)
    }

    public init(agentId: String, agentType: String, startedAt: Date) {
        self.agentId = agentId
        self.agentType = agentType
        self.startedAt = startedAt
    }
}

// MARK: - 会话错误

public enum SessionError: LocalizedError, Sendable, Equatable {
    case fileURLMissing
    case fileNotFound(URL)
    case decodeFailed(String)
    case lockFailed(String)

    public var errorDescription: String? {
        switch self {
        case .fileURLMissing: return "文件路径未设置"
        case .fileNotFound(let url): return "文件不存在: \(url.path)"
        case .decodeFailed(let msg): return "解析失败: \(msg)"
        case .lockFailed(let msg): return "获取文件锁失败: \(msg)"
        }
    }
}

// MARK: - 会话数据模型

public struct Session: Codable, Equatable, Sendable {
    public let sessionId: String
    public let cwd: String
    public var status: SessionState
    public var lastActivity: Date
    public var branch: String?
    public var source: String?
    public var sessionName: String?
    public var lastTool: String?
    public var lastToolDetail: String?
    public var lastPrompt: String?
    public var notificationMessage: String?
    public var activeSubagents: [SubagentInfo]
    public var pid: UInt32?
    public var pidStartTime: TimeInterval?
    public var contextUsage: Double?
    public var contextTokensUsed: Int?
    public var contextTokensTotal: Int?
    public var contextInputTokens: Int?
    public var contextOutputTokens: Int?
    public var contextReasoningTokens: Int?
    public var toolUsage: [ToolUsage]?
    public var skillUsage: [ToolUsage]?
    public var transcriptPath: String?
    public var transcriptOffset: Int?
    public var contextLimit: Int?
    public var fileURL: URL?

    enum CodingKeys: String, CodingKey {
        case sessionId, session_id
        case cwd
        case status
        case lastActivity, last_activity
        case branch
        case source
        case sessionName, session_name
        case lastTool, last_tool
        case lastToolDetail, last_tool_detail
        case lastPrompt, last_prompt
        case notificationMessage, notification_message
        case activeSubagents, active_subagents
        case pid
        case pidStartTime, pid_start_time
        case contextUsage, context_usage
        case contextTokensUsed, context_tokens_used
        case contextTokensTotal, context_tokens_total
        case contextInputTokens, context_input_tokens
        case contextOutputTokens, context_output_tokens
        case contextReasoningTokens, context_reasoning_tokens
        case toolUsage, tool_usage
        case skillUsage, skill_usage
        case transcriptPath, transcript_path
        case transcriptOffset, transcript_offset
        case contextLimit, context_limit
    }

    public init(
        sessionId: String,
        cwd: String,
        status: SessionState = .idle,
        lastActivity: Date = Date(),
        branch: String? = nil,
        source: String? = nil,
        sessionName: String? = nil,
        lastTool: String? = nil,
        lastToolDetail: String? = nil,
        lastPrompt: String? = nil,
        notificationMessage: String? = nil,
        activeSubagents: [SubagentInfo] = [],
        pid: UInt32? = nil,
        pidStartTime: TimeInterval? = nil,
        contextUsage: Double? = nil,
        contextTokensUsed: Int? = nil,
        contextTokensTotal: Int? = nil,
        contextInputTokens: Int? = nil,
        contextOutputTokens: Int? = nil,
        contextReasoningTokens: Int? = nil,
        toolUsage: [ToolUsage]? = nil,
        skillUsage: [ToolUsage]? = nil,
        transcriptPath: String? = nil,
        transcriptOffset: Int? = nil,
        contextLimit: Int? = nil,
        fileURL: URL? = nil
    ) {
        self.sessionId = sessionId
        self.cwd = cwd
        self.status = status
        self.lastActivity = lastActivity
        self.branch = branch
        self.source = source
        self.sessionName = sessionName
        self.lastTool = lastTool
        self.lastToolDetail = lastToolDetail
        self.lastPrompt = lastPrompt
        self.notificationMessage = notificationMessage
        self.activeSubagents = activeSubagents
        self.pid = pid
        self.pidStartTime = pidStartTime
        self.contextUsage = contextUsage
        self.contextTokensUsed = contextTokensUsed
        self.contextTokensTotal = contextTokensTotal
        self.contextInputTokens = contextInputTokens
        self.contextOutputTokens = contextOutputTokens
        self.contextReasoningTokens = contextReasoningTokens
        self.toolUsage = toolUsage
        self.skillUsage = skillUsage
        self.transcriptPath = transcriptPath
        self.transcriptOffset = transcriptOffset
        self.contextLimit = contextLimit
        self.fileURL = fileURL
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        sessionId = try Self.decodeFirst(container, key1: .sessionId, key2: .session_id) { c, k in try c.decode(String.self, forKey: k) }
        cwd = try container.decode(String.self, forKey: .cwd)
        status = try container.decodeIfPresent(SessionState.self, forKey: .status) ?? .idle
        lastActivity = try Self.decodeFirst(container, key1: .lastActivity, key2: .last_activity) { c, k in try c.decode(Date.self, forKey: k) }
        branch = try container.decodeIfPresent(String.self, forKey: .branch)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        sessionName = try Self.decodeFirstOptional(container, key1: .sessionName, key2: .session_name) { c, k in try c.decodeIfPresent(String.self, forKey: k) }
        lastTool = try Self.decodeFirstOptional(container, key1: .lastTool, key2: .last_tool) { c, k in try c.decodeIfPresent(String.self, forKey: k) }
        lastToolDetail = try Self.decodeFirstOptional(container, key1: .lastToolDetail, key2: .last_tool_detail) { c, k in try c.decodeIfPresent(String.self, forKey: k) }
        lastPrompt = try Self.decodeFirstOptional(container, key1: .lastPrompt, key2: .last_prompt) { c, k in try c.decodeIfPresent(String.self, forKey: k) }
        notificationMessage = try Self.decodeFirstOptional(container, key1: .notificationMessage, key2: .notification_message) { c, k in try c.decodeIfPresent(String.self, forKey: k) }
        activeSubagents = try Self.decodeFirstOptional(container, key1: .activeSubagents, key2: .active_subagents) { c, k in try c.decodeIfPresent([SubagentInfo].self, forKey: k) } ?? []
        pid = try container.decodeIfPresent(UInt32.self, forKey: .pid)
        pidStartTime = try Self.decodeFirstOptional(container, key1: .pidStartTime, key2: .pid_start_time) { c, k in try c.decodeIfPresent(TimeInterval.self, forKey: k) }
        contextUsage = try Self.decodeFirstOptional(container, key1: .contextUsage, key2: .context_usage) { c, k in try c.decodeIfPresent(Double.self, forKey: k) }
        contextTokensUsed = try Self.decodeFirstOptional(container, key1: .contextTokensUsed, key2: .context_tokens_used) { c, k in try c.decodeIfPresent(Int.self, forKey: k) }
        contextTokensTotal = try Self.decodeFirstOptional(container, key1: .contextTokensTotal, key2: .context_tokens_total) { c, k in try c.decodeIfPresent(Int.self, forKey: k) }
        contextInputTokens = try Self.decodeFirstOptional(container, key1: .contextInputTokens, key2: .context_input_tokens) { c, k in try c.decodeIfPresent(Int.self, forKey: k) }
        contextOutputTokens = try Self.decodeFirstOptional(container, key1: .contextOutputTokens, key2: .context_output_tokens) { c, k in try c.decodeIfPresent(Int.self, forKey: k) }
        contextReasoningTokens = try Self.decodeFirstOptional(container, key1: .contextReasoningTokens, key2: .context_reasoning_tokens) { c, k in try c.decodeIfPresent(Int.self, forKey: k) }
        toolUsage = try Self.decodeFirstOptional(container, key1: .toolUsage, key2: .tool_usage) { c, k in try c.decodeIfPresent([ToolUsage].self, forKey: k) }
        skillUsage = try Self.decodeFirstOptional(container, key1: .skillUsage, key2: .skill_usage) { c, k in try c.decodeIfPresent([ToolUsage].self, forKey: k) }
        transcriptPath = try Self.decodeFirstOptional(container, key1: .transcriptPath, key2: .transcript_path) { c, k in try c.decodeIfPresent(String.self, forKey: k) }
        transcriptOffset = try Self.decodeFirstOptional(container, key1: .transcriptOffset, key2: .transcript_offset) { c, k in try c.decodeIfPresent(Int.self, forKey: k) }
        contextLimit = try Self.decodeFirstOptional(container, key1: .contextLimit, key2: .context_limit) { c, k in try c.decodeIfPresent(Int.self, forKey: k) }
        fileURL = nil
    }

    private static func decodeFirst<T: Decodable>(_ container: KeyedDecodingContainer<CodingKeys>, key1: CodingKeys, key2: CodingKeys, decode: (KeyedDecodingContainer<CodingKeys>, CodingKeys) throws -> T) throws -> T {
        if let value = try container.decodeIfPresent(T.self, forKey: key1) { return value }
        return try decode(container, key2)
    }

    private static func decodeFirstOptional<T: Decodable>(_ container: KeyedDecodingContainer<CodingKeys>, key1: CodingKeys, key2: CodingKeys, decode: (KeyedDecodingContainer<CodingKeys>, CodingKeys) throws -> T?) throws -> T? {
        if let value = try container.decodeIfPresent(T.self, forKey: key1) { return value }
        return try decode(container, key2)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .session_id) // 输出蛇形键名保持兼容
        try container.encode(cwd, forKey: .cwd)
        try container.encode(status, forKey: .status)
        try container.encode(lastActivity, forKey: .last_activity) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(branch, forKey: .branch)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(sessionName, forKey: .session_name) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(lastTool, forKey: .last_tool) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(lastToolDetail, forKey: .last_tool_detail) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(lastPrompt, forKey: .last_prompt) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(notificationMessage, forKey: .notification_message) // 输出蛇形键名保持兼容
        try container.encode(activeSubagents, forKey: .active_subagents) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(pid, forKey: .pid)
        try container.encodeIfPresent(pidStartTime, forKey: .pid_start_time) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(contextUsage, forKey: .context_usage) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(contextTokensUsed, forKey: .context_tokens_used) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(contextTokensTotal, forKey: .context_tokens_total) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(contextInputTokens, forKey: .context_input_tokens) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(contextOutputTokens, forKey: .context_output_tokens) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(contextReasoningTokens, forKey: .context_reasoning_tokens) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(toolUsage, forKey: .tool_usage) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(skillUsage, forKey: .skill_usage) // 输出蛇形键名保持兼容
        try container.encodeIfPresent(transcriptPath, forKey: .transcript_path)
        try container.encodeIfPresent(transcriptOffset, forKey: .transcript_offset)
        try container.encodeIfPresent(contextLimit, forKey: .context_limit)
    }

    public func writeToFile() throws {
        guard let url = fileURL else { throw SessionError.fileURLMissing }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        // 不使用 .atomic：atomic write 会创建新 inode，导致 App 端 DispatchSource 的 fd 失效
        // CLI 端已有 flock 保护读写周期，无需 atomic 保证
        try data.write(to: url, options: [])
    }

    public static func loadFromFile(url: URL) throws -> Session {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var session = try decoder.decode(Session.self, from: data)
        session.fileURL = url
        return session
    }
}

// MARK: - 共享工具扩展

public extension String {
    /// 缩短工作目录路径，保留最后两级
    func shortenedCwd() -> String {
        let components = split(separator: "/")
        guard components.count > 3 else { return self }
        return ".../" + components.suffix(2).joined(separator: "/")
    }
}

public extension Session {
    /// 工具来源显示名称
    var toolDisplayName: String {
        switch source {
        case "opencode": return "OpenCode"
        default: return "Claude"
        }
    }

    /// 工具来源图标
    var toolSourceIcon: String {
        switch source {
        case "opencode": return "terminal"
        default: return "cpu"
        }
    }
}

